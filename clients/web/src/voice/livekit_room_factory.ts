import { LiveKitMicrophoneAdapter } from './noise_suppression/livekit_microphone_adapter'
import { RnnoiseTrackProcessor } from './noise_suppression/rnnoise_track_processor'
import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'
import type { VoiceRoom } from './livekit_gateway'
import { adaptiveMediaRoomOptions } from './media_publishing'
import { bindScreenProfile } from './screen_profile/bind'
import { BoundedVoiceReconnectPolicy } from './bounded_voice_reconnect_policy'
import { inspectLiveKitScreenDiagnostics, type LiveKitScreenVideoTrack } from './screen_livekit_diagnostics'
import { readVoiceConnectionStats } from './voice_connection_quality'
import { accountIdFromMetadata } from './participant_identity'
import { captureLocalScreenThumbnails } from './screen_thumbnail'

export function wireLiveKitRoom(
  room: VoiceRoom,
  viewer: Pick<ReturnType<typeof bindLiveKitScreenViewer>, 'clear' | 'refresh' | 'subscribeMicrophones' | 'subscribeScreenThumbnails'>,
): VoiceRoom {
  const connect = room.connect.bind(room)
  const disconnect = room.disconnect.bind(room)
  room.connect = async (url, token, options) => {
    await connect(url, token, { ...options, autoSubscribe: false })
    viewer.subscribeMicrophones()
    viewer.subscribeScreenThumbnails()
    viewer.refresh()
  }
  room.disconnect = async () => {
    const microphoneCleanup = room.disposeMicrophone?.()
    viewer.clear()
    try { await disconnect() } finally { await microphoneCleanup }
  }
  return room
}

export async function defaultLiveKitRoomFactory(): Promise<VoiceRoom> {
  const { Room, RoomEvent, Track, LocalAudioTrack } = await import('livekit-client')
  const liveKitRoom = new Room({ ...adaptiveMediaRoomOptions, reconnectPolicy: new BoundedVoiceReconnectPolicy() })
  const viewer = bindLiveKitScreenViewer(liveKitRoom as unknown as LiveKitScreenViewerRoom, {
    activeSpeakersChanged: RoomEvent.ActiveSpeakersChanged,
    localTrackPublished: RoomEvent.LocalTrackPublished,
    localTrackUnpublished: RoomEvent.LocalTrackUnpublished,
    participantConnected: RoomEvent.ParticipantConnected,
    participantDisconnected: RoomEvent.ParticipantDisconnected,
    trackPublished: RoomEvent.TrackPublished,
    trackMuted: RoomEvent.TrackMuted,
    trackSubscribed: RoomEvent.TrackSubscribed,
    trackUnmuted: RoomEvent.TrackUnmuted,
    trackUnpublished: RoomEvent.TrackUnpublished,
    trackUnsubscribed: RoomEvent.TrackUnsubscribed,
  }, {
    microphone: Track.Source.Microphone,
    screenAudio: Track.Source.ScreenShareAudio,
    screenVideo: Track.Source.ScreenShare,
  })
  let stopThumbnails: (() => void) | null = null
  liveKitRoom.on(RoomEvent.LocalTrackPublished, (publication) => {
    if (publication.source !== Track.Source.ScreenShare || !publication.videoTrack) return
    stopThumbnails?.()
    const local = liveKitRoom.localParticipant
    const participantId = accountIdFromMetadata(local.metadata) ?? local.identity
    stopThumbnails = captureLocalScreenThumbnails(publication.videoTrack, (bytes) => viewer.viewer.setThumbnail(participantId, bytes))
  })
  liveKitRoom.on(RoomEvent.LocalTrackUnpublished, (publication) => {
    if (publication.source !== Track.Source.ScreenShare) return
    stopThumbnails?.()
    stopThumbnails = null
    const local = liveKitRoom.localParticipant
    viewer.viewer.removeThumbnail(accountIdFromMetadata(local.metadata) ?? local.identity)
  })
  liveKitRoom.on(RoomEvent.Disconnected, () => { stopThumbnails?.(); stopThumbnails = null })
  const room = wireLiveKitRoom(liveKitRoom as unknown as VoiceRoom, viewer)
  room.screenViewer = viewer.viewer
  room.participantCards = viewer.participants
  room.remoteVoices = viewer.remoteVoices
  room.setDeafened = viewer.setDeafened
  const microphone = new LiveKitMicrophoneAdapter({
    createTrack: async (options) => {
      const tracks = await liveKitRoom.localParticipant.createTracks({ audio: options, video: false })
      const audio = tracks.find((track) => track instanceof LocalAudioTrack)
      if (!audio || tracks.length !== 1) {
        tracks.forEach((track) => track.stop())
        throw new Error('Микрофон не предоставил аудиодорожку.')
      }
      return audio as InstanceType<typeof LocalAudioTrack>
    },
    publishTrack: (track, options) => liveKitRoom.localParticipant.publishTrack(track, { ...options, source: Track.Source.Microphone }),
    unpublishTrack: (track) => liveKitRoom.localParticipant.unpublishTrack(track, false),
    createProcessor: (callbacks) => new RnnoiseTrackProcessor(callbacks),
  })
  room.setMicrophone = (enabled, options) => microphone.setEnabled(enabled, options)
  room.disposeMicrophone = () => microphone.dispose()
  room.applyMicrophoneProcessing = (options) => microphone.setProcessing(options)
  room.readAudioProcessingSettings = () => microphone.readCaptureSettings()
  room.readMicrophoneTrack = () => microphone.readOutputTrack()
  room.readNoiseSuppressionState = () => microphone.runtimeState
  room.onNoiseSuppressionState = (listener) => microphone.subscribe(listener)
  const switchDevice = liveKitRoom.switchActiveDevice.bind(liveKitRoom)
  room.switchActiveDevice = (kind, deviceId) => kind === 'audioinput' ? microphone.switchDevice(deviceId) : switchDevice(kind, deviceId)
  liveKitRoom.on(RoomEvent.Disconnected, () => { void microphone.dispose().catch(() => undefined) })
  room.readScreenDiagnostics = async () => {
    const video = liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack as LiveKitScreenVideoTrack | undefined
    const audio = liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShareAudio)?.audioTrack
    return inspectLiveKitScreenDiagnostics(video, Boolean(audio), liveKitRoom.localParticipant.connectionQuality)
  }
  room.readVoiceConnectionStats = async () => {
    const manager = liveKitRoom.engine.pcManager
    const reports = await Promise.all([manager?.publisher.getStats(), manager?.subscriber?.getStats()])
    const samples = reports.map((report) => readVoiceConnectionStats(liveKitRoom.localParticipant.connectionQuality, report?.values()))
    return samples.find((sample) => sample.pingMs !== null) ?? samples[0]!
  }
  const stopProfileChecks = bindScreenProfile(room, () => liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack)
  liveKitRoom.on(RoomEvent.LocalTrackUnpublished, (publication) => { if (publication.source === Track.Source.ScreenShare) stopProfileChecks() })
  liveKitRoom.on(RoomEvent.Disconnected, stopProfileChecks)
  return room
}
