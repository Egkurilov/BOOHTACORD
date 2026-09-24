import { LiveKitScreenRegistry, type ScreenParticipantPublication } from './livekit_screen_registry'
import { bindLiveKitRemoteParticipants, type LiveKitRemoteParticipant } from './livekit_remote_participants'
import { accountIdFromMetadata } from './participant_identity'
import { RemoteVoicePlayback, type RemoteVoiceTrack } from './remote_voice_playback'
import { ScreenViewerController, type ScreenViewerPublication } from './screen_viewer_controller'

export interface LiveKitScreenViewerRoom {
  localParticipant?: LiveKitRemoteParticipant
  on(event: unknown, listener: (...arguments_: any[]) => void): unknown
  remoteParticipants: Map<string, LiveKitRemoteParticipant>
}

export interface LiveKitScreenViewerEvents {
  activeSpeakersChanged: unknown
  localTrackPublished: unknown
  localTrackUnpublished: unknown
  participantConnected: unknown
  participantDisconnected: unknown
  trackMuted: unknown
  trackPublished: unknown
  trackSubscribed: unknown
  trackUnmuted: unknown
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

export type RemoteVoicePlaybackController = Pick<RemoteVoicePlayback, 'attach' | 'cards' | 'clear' | 'detach' | 'forget' | 'isSpeaking' | 'onChange' | 'setDeafened' | 'setSpeaking' | 'setVolume'>

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
  const participants = (): ScreenParticipantPublication[] => {
    const remote = [...room.remoteParticipants.values()].map((participant) => ({
      accountId: accountId(participant) ?? undefined,
      audio: participant.getTrackPublication(sources.screenAudio),
      identity: participantId(participant),
      name: participant.name,
      video: participant.getTrackPublication(sources.screenVideo),
    }))
    const local = room.localParticipant
    const localVideo = local?.getTrackPublication(sources.screenVideo)
    return [...remote, ...(local && localVideo ? [{
      accountId: accountId(local) ?? undefined,
      identity: participantId(local),
      isLocal: true,
      name: 'Ваш экран',
      video: localVideo,
    }] : [])]
  }
  const refresh = () => {
    registry.refresh(participants(), viewer.selectedId)
    participantCards.refresh()
    viewer.reconcile()
  }
  room.on(events.localTrackPublished, refresh)
  room.on(events.localTrackUnpublished, refresh)
  const subscribeMicrophones = () => room.remoteParticipants.forEach((participant) => participant.getTrackPublication(sources.microphone)?.setSubscribed?.(true))
  room.on(events.activeSpeakersChanged, (speakers: LiveKitRemoteParticipant[]) => {
    const active = new Set(speakers.map(participantId))
    const local = room.localParticipant
    if (local) voicePlayback.setSpeaking(participantId(local), active.has(participantId(local)))
    room.remoteParticipants.forEach((participant) => voicePlayback.setSpeaking(participantId(participant), active.has(participantId(participant))))
  })
  room.on(events.participantConnected, refresh)
  room.on(events.participantDisconnected, (participant: LiveKitRemoteParticipant) => {
    voicePlayback.forget(participantId(participant))
    refresh()
  })
  room.on(events.trackPublished, (publication: { source?: unknown }) => {
    if (publication.source === sources.microphone) (publication as ScreenViewerPublication).setSubscribed?.(true)
    refresh()
  })
  const refreshMicrophoneState = (publication: { source?: unknown }) => {
    if (publication.source === sources.microphone) refresh()
  }
  room.on(events.trackMuted, refreshMicrophoneState)
  room.on(events.trackUnmuted, refreshMicrophoneState)
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
