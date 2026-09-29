import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'
import type { VoiceRoom } from './livekit_gateway'
import { adaptiveMediaRoomOptions } from './media_publishing'
import { BoundedVoiceReconnectPolicy } from './bounded_voice_reconnect_policy'
import { inspectLiveKitScreenDiagnostics, type LiveKitScreenVideoTrack } from './screen_livekit_diagnostics'
import { readVoiceConnectionStats } from './voice_connection_quality'

export function wireLiveKitRoom(
  room: VoiceRoom,
  viewer: Pick<ReturnType<typeof bindLiveKitScreenViewer>, 'clear' | 'refresh' | 'subscribeMicrophones'>,
): VoiceRoom {
  const connect = room.connect.bind(room)
  const disconnect = room.disconnect.bind(room)
  room.connect = async (url, token, options) => {
    await connect(url, token, { ...options, autoSubscribe: false })
    viewer.subscribeMicrophones()
    viewer.refresh()
  }
  room.disconnect = async () => {
    viewer.clear()
    await disconnect()
  }
  return room
}

export async function defaultLiveKitRoomFactory(): Promise<VoiceRoom> {
  const { Room, RoomEvent, Track } = await import('livekit-client')
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
  const room = wireLiveKitRoom(liveKitRoom as unknown as VoiceRoom, viewer)
  room.screenViewer = viewer.viewer
  room.participantCards = viewer.participants
  room.remoteVoices = viewer.remoteVoices
  room.setDeafened = viewer.setDeafened
  room.applyMicrophoneProcessing = async (options) => {
    await liveKitRoom.localParticipant.getTrackPublication(Track.Source.Microphone)?.audioTrack?.applyConstraints(options)
  }
  room.readAudioProcessingSettings = () => liveKitRoom.localParticipant.getTrackPublication(Track.Source.Microphone)?.audioTrack?.mediaStreamTrack.getSettings()
  room.readScreenDiagnostics = async () => {
    const video = liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack as LiveKitScreenVideoTrack | undefined
    const audio = liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShareAudio)?.audioTrack
    return inspectLiveKitScreenDiagnostics(video, Boolean(audio), liveKitRoom.localParticipant.connectionQuality)
  }
  room.readVoiceConnectionStats = async () => {
    const audio = liveKitRoom.localParticipant.getTrackPublication(Track.Source.Microphone)?.audioTrack
    const report = await audio?.getRTCStatsReport()
    return readVoiceConnectionStats(liveKitRoom.localParticipant.connectionQuality, report?.values())
  }
  return room
}
