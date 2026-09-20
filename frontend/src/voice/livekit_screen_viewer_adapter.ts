import { LiveKitScreenRegistry, type RemoteScreenParticipant } from './livekit_screen_registry'
import { bindLiveKitRemoteParticipants, type LiveKitRemoteParticipant } from './livekit_remote_participants'
import { accountIdFromMetadata } from './participant_identity'
import { RemoteVoicePlayback, type RemoteVoiceCard, type RemoteVoiceTrack } from './remote_voice_playback'
import { ScreenViewerController, type ScreenViewerPublication } from './screen_viewer_controller'

export interface LiveKitScreenViewerRoom {
  on(event: unknown, listener: (...arguments_: any[]) => void): unknown
  remoteParticipants: Map<string, LiveKitRemoteParticipant>
}

export interface LiveKitScreenViewerEvents {
  activeSpeakersChanged: unknown
  participantConnected: unknown
  participantDisconnected: unknown
  trackPublished: unknown
  trackSubscribed: unknown
  trackUnpublished: unknown
  trackUnsubscribed: unknown
}

export interface LiveKitScreenSources {
  microphone: unknown
  screenAudio: unknown
  screenVideo: unknown
}

export interface LiveKitScreenViewerBinding {
  clear(): void
  refresh(): void
  participants: ReturnType<typeof bindLiveKitRemoteParticipants>
  remoteVoices: RemoteVoicePlaybackController
  setDeafened(deafened: boolean): void
  subscribeMicrophones(): void
  viewer: ScreenViewerController
}

export interface RemoteVoicePlaybackController {
  attach(participantId: string, track: RemoteVoiceTrack, name?: string, accountId?: string | null): void
  cards(): RemoteVoiceCard[]
  clear(): void
  detach(participantId: string): void
  forget(participantId: string): void
  isSpeaking(participantId: string): boolean
  onChange(listener: () => void): () => void
  setDeafened(deafened: boolean): void
  setSpeaking(participantId: string, speaking: boolean): void
  setVolume(participantId: string, percent: number): void
}

export function bindLiveKitScreenViewer(
  room: LiveKitScreenViewerRoom,
  events: LiveKitScreenViewerEvents,
  sources: LiveKitScreenSources,
  voicePlayback: RemoteVoicePlaybackController = new RemoteVoicePlayback(),
): LiveKitScreenViewerBinding {
  const registry = new LiveKitScreenRegistry()
  const viewer = new ScreenViewerController(() => registry.streams())
  const accountId = (participant: LiveKitRemoteParticipant) => accountIdFromMetadata(participant.metadata)
  const participantId = (participant: LiveKitRemoteParticipant) => accountId(participant) ?? participant.identity
  const participantCards = bindLiveKitRemoteParticipants(() => room.remoteParticipants.values(), sources.microphone, participantId, accountId, voicePlayback)
  const participants = (): RemoteScreenParticipant[] => [...room.remoteParticipants.values()].map((participant) => ({
    accountId: accountId(participant) ?? undefined,
    audio: participant.getTrackPublication(sources.screenAudio),
    identity: participantId(participant),
    name: participant.name,
    video: participant.getTrackPublication(sources.screenVideo),
  }))
  const refresh = () => {
    registry.refresh(participants(), viewer.selectedId)
    participantCards.refresh()
    viewer.reconcile()
  }
  const subscribeMicrophones = () => room.remoteParticipants.forEach((participant) => {
    participant.getTrackPublication(sources.microphone)?.setSubscribed(true)
  })
  room.on(events.activeSpeakersChanged, (speakers: LiveKitRemoteParticipant[]) => {
    const active = new Set(speakers.map(participantId))
    room.remoteParticipants.forEach((participant) => voicePlayback.setSpeaking(participantId(participant), active.has(participantId(participant))))
  })
  room.on(events.participantConnected, refresh)
  room.on(events.participantDisconnected, (participant: LiveKitRemoteParticipant) => {
    voicePlayback.forget(participantId(participant))
    refresh()
  })
  room.on(events.trackPublished, (publication: { source?: unknown }) => {
    if (publication.source === sources.microphone) (publication as ScreenViewerPublication).setSubscribed(true)
    refresh()
  })
  room.on(events.trackSubscribed, (track: RemoteVoiceTrack, publication: { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.microphone) voicePlayback.attach(participantId(participant), track, participant.name, accountId(participant))
    refresh()
  })
  room.on(events.trackUnpublished, refresh)
  room.on(events.trackUnsubscribed, (_track: unknown, publication: { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.microphone) voicePlayback.detach(participantId(participant))
    refresh()
  })
  return {
    clear: () => { voicePlayback.clear(); viewer.clear() },
    refresh,
    participants: participantCards,
    remoteVoices: voicePlayback,
    setDeafened: (deafened) => { voicePlayback.setDeafened(deafened); viewer.setDeafened(deafened) },
    subscribeMicrophones,
    viewer,
  }
}
