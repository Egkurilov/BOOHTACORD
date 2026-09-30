import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'
import type { VoiceRoom } from './livekit_gateway'
import { adaptiveMediaRoomOptions, screenShareMaxBitrate, type ScreenProfile, type ScreenResolution, type ScreenFrameRate } from './media_publishing'
import { BoundedVoiceReconnectPolicy } from './bounded_voice_reconnect_policy'
import { inspectLiveKitScreenDiagnostics, type LiveKitScreenVideoTrack } from './screen_livekit_diagnostics'
import { readVoiceConnectionStats } from './voice_connection_quality'
import { accountIdFromMetadata } from './participant_identity'
import { publishScreenThumbnails, screenThumbnailTopic, validScreenThumbnail } from './screen_thumbnail'

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
  let stopThumbnails: (() => void) | null = null
  liveKitRoom.on(RoomEvent.LocalTrackPublished, (publication) => {
    if (publication.source !== Track.Source.ScreenShare || !publication.videoTrack) return
    stopThumbnails?.()
    const local = liveKitRoom.localParticipant
    const participantId = accountIdFromMetadata(local.metadata) ?? local.identity
    stopThumbnails = publishScreenThumbnails(publication.videoTrack, local, (bytes) => viewer.viewer.setThumbnail(participantId, bytes))
  })
  liveKitRoom.on(RoomEvent.LocalTrackUnpublished, (publication) => {
    if (publication.source !== Track.Source.ScreenShare) return
    stopThumbnails?.()
    stopThumbnails = null
    const local = liveKitRoom.localParticipant
    viewer.viewer.removeThumbnail(accountIdFromMetadata(local.metadata) ?? local.identity)
  })
  liveKitRoom.on(RoomEvent.Disconnected, () => { stopThumbnails?.(); stopThumbnails = null })
  liveKitRoom.on(RoomEvent.DataReceived, (bytes, participant, _kind, topic) => {
    if (topic !== screenThumbnailTopic || !participant || !validScreenThumbnail(bytes)) return
    viewer.viewer.setThumbnail(accountIdFromMetadata(participant.metadata) ?? participant.identity, bytes)
  })
  liveKitRoom.on(RoomEvent.TrackUnpublished, (publication, participant) => {
    if (publication.source === Track.Source.ScreenShare) {
      viewer.viewer.removeThumbnail(accountIdFromMetadata(participant.metadata) ?? participant.identity)
    }
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
    const manager = liveKitRoom.engine.pcManager
    const reports = await Promise.all([manager?.publisher.getStats(), manager?.subscriber?.getStats()])
    const samples = reports.map((report) => readVoiceConnectionStats(liveKitRoom.localParticipant.connectionQuality, report?.values()))
    return samples.find((sample) => sample.pingMs !== null) ?? samples[0]!
  }
  room.localParticipant.updateScreenShareProfile = async (profile: ScreenProfile) => {
    const match = /^P(720|1080|1440)_(15|30|60)$/.exec(profile)
    if (!match) throw new Error('Некорректный профиль демонстрации.')
    const resolution = Number(match[1]) as ScreenResolution
    const frameRate = Number(match[2]) as ScreenFrameRate
    const track = liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack
    const sender = track?.sender
    if (!sender) throw new Error('Активная видеодорожка демонстрации недоступна.')
    const settings = track.mediaStreamTrack.getSettings()
    const sourceEdge = Math.max(settings.width ?? 0, settings.height ?? 0)
    const targetEdge = resolution === 720 ? 1280 : resolution === 1080 ? 1920 : 2560
    const scale = Math.max(1, sourceEdge / targetEdge)
    const parameters = sender.getParameters()
    if (!parameters.encodings?.length) throw new Error('Видеоэнкодер не предоставил параметры качества.')
    const baseScale = Math.min(...parameters.encodings.map((encoding) => encoding.scaleResolutionDownBy ?? 1))
    const bitrate = screenShareMaxBitrate(resolution, frameRate)
    parameters.encodings.forEach((encoding) => {
      const relativeScale = (encoding.scaleResolutionDownBy ?? 1) / baseScale
      encoding.maxBitrate = Math.max(200_000, Math.round(bitrate / (relativeScale * relativeScale)))
      encoding.maxFramerate = frameRate
      encoding.scaleResolutionDownBy = scale * relativeScale
    })
    await sender.setParameters(parameters)
  }
  return room
}
