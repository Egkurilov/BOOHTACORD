import { LiveKitScreenRegistry, type ScreenParticipantPublication } from './livekit_screen_registry'
import { bindLiveKitRemoteParticipants, type LiveKitRemoteParticipant } from './livekit_remote_participants'
import { accountIdFromMetadata } from './participant_identity'
import { RemoteVoicePlayback, type RemoteVoiceTrack } from './remote_voice_playback'
import { ScreenViewerController, type ScreenViewerPublication } from './screen_viewer_controller'
import { captureScreenThumbnailFromTrack, type ThumbnailVideoTrack } from './screen_thumbnail'

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
  subscribeScreenThumbnails(): void
  subscribeMicrophones(): void
  viewer: ScreenViewerController
}

export type RemoteVoicePlaybackController = Pick<RemoteVoicePlayback, 'attach' | 'cards' | 'clear' | 'detach' | 'forget' | 'isSpeaking' | 'onChange' | 'setDeafened' | 'setSpeaking' | 'setVolume'>

export function bindLiveKitScreenViewer(
  room: LiveKitScreenViewerRoom,
  events: LiveKitScreenViewerEvents,
  sources: LiveKitScreenSources,
  voicePlayback: RemoteVoicePlaybackController = new RemoteVoicePlayback(),
  captureThumbnail: typeof captureScreenThumbnailFromTrack = captureScreenThumbnailFromTrack,
): LiveKitScreenViewerBinding {
  const registry = new LiveKitScreenRegistry()
  const viewer = new ScreenViewerController(() => registry.streams())
  const previewing = new Set<string>()
  const pendingPreviews = new Map<string, { participant: LiveKitRemoteParticipant; publication: ScreenViewerPublication }>()
  const capturingPreviews = new Set<string>()
  let roomActive = true
  let activePreviewId: string | null = null
  let activePreviewPublication: ScreenViewerPublication | null = null
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
    registry.refresh(participants(), viewer.selectedId, previewing)
    participantCards.refresh()
    viewer.reconcile()
  }
  room.on(events.localTrackPublished, refresh)
  room.on(events.localTrackUnpublished, refresh)
  const subscribeMicrophones = () => room.remoteParticipants.forEach((participant) => participant.getTrackPublication(sources.microphone)?.setSubscribed?.(true))
  const screenId = (participant: LiveKitRemoteParticipant) => `${participantId(participant)}:screen`
  const startNextScreenPreview = () => {
    if (!roomActive || activePreviewId) return
    for (const [id, candidate] of pendingPreviews) {
      pendingPreviews.delete(id)
      if (
        candidate.participant.getTrackPublication(sources.screenVideo) !== candidate.publication ||
        candidate.publication.isMuted ||
        viewer.selectedId === id
      ) continue
      activePreviewId = id
      activePreviewPublication = candidate.publication
      previewing.add(id)
      candidate.publication.setSubscribed?.(true)
      refresh()
      return
    }
  }
  const finishScreenPreview = (id: string, expectedPublication?: ScreenViewerPublication) => {
    const pendingPublication = pendingPreviews.get(id)?.publication
    if (expectedPublication && pendingPublication !== expectedPublication && activePreviewPublication !== expectedPublication) return
    capturingPreviews.delete(id)
    pendingPreviews.delete(id)
    if (activePreviewId !== id) return
    activePreviewId = null
    activePreviewPublication = null
    previewing.delete(id)
    refresh()
    startNextScreenPreview()
  }
  const subscribeScreenThumbnail = (participant: LiveKitRemoteParticipant, publication?: ScreenViewerPublication) => {
    const id = screenId(participant)
    if (!publication || publication.isMuted || viewer.selectedId === id || activePreviewId === id) return
    pendingPreviews.set(id, { participant, publication })
    startNextScreenPreview()
  }
  const subscribeScreenThumbnails = () => room.remoteParticipants.forEach((participant) => subscribeScreenThumbnail(participant, participant.getTrackPublication(sources.screenVideo)))
  room.on(events.activeSpeakersChanged, (speakers: LiveKitRemoteParticipant[]) => {
    const active = new Set(speakers.map(participantId))
    const local = room.localParticipant
    if (local) voicePlayback.setSpeaking(participantId(local), active.has(participantId(local)))
    room.remoteParticipants.forEach((participant) => voicePlayback.setSpeaking(participantId(participant), active.has(participantId(participant))))
  })
  room.on(events.participantConnected, refresh)
  room.on(events.participantDisconnected, (participant: LiveKitRemoteParticipant) => {
    const id = screenId(participant)
    pendingPreviews.delete(id)
    finishScreenPreview(id)
    voicePlayback.forget(participantId(participant))
    viewer.removeThumbnail(participantId(participant))
    refresh()
  })
  room.on(events.trackPublished, (publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.microphone) (publication as ScreenViewerPublication).setSubscribed?.(true)
    if (publication.source === sources.screenVideo) subscribeScreenThumbnail(participant, publication)
    refresh()
  })
  const refreshMicrophoneState = (publication: { source?: unknown }) => {
    if (publication.source === sources.microphone) refresh()
  }
  room.on(events.trackMuted, refreshMicrophoneState)
  room.on(events.trackUnmuted, (publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.screenVideo) subscribeScreenThumbnail(participant, publication)
    else refreshMicrophoneState(publication)
  })
  room.on(events.trackSubscribed, (track: RemoteVoiceTrack, publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.microphone) voicePlayback.attach(participantId(participant), track, participant.name, accountId(participant))
    if (publication.source === sources.screenVideo) {
      const id = screenId(participant)
      if (activePreviewId === id && !capturingPreviews.has(id) && viewer.selectedId !== id) {
        capturingPreviews.add(id)
        void Promise.resolve().then(() => captureThumbnail(track as unknown as ThumbnailVideoTrack, (bytes) => viewer.setThumbnail(participantId(participant), bytes), {
          isActive: () => roomActive && room.remoteParticipants.get(participant.identity) === participant && publication.track === track,
        })).catch(() => false).finally(() => finishScreenPreview(id, publication))
      } else if (activePreviewId === id && viewer.selectedId === id) finishScreenPreview(id, publication)
    }
    refresh()
  })
  room.on(events.trackUnpublished, (publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.screenVideo) {
      finishScreenPreview(screenId(participant), publication)
      viewer.removeThumbnail(participantId(participant))
    }
    refresh()
  })
  room.on(events.trackUnsubscribed, (_track: unknown, publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.microphone) voicePlayback.detach(participantId(participant))
    if (publication.source === sources.screenVideo) {
      finishScreenPreview(screenId(participant), publication)
    }
    refresh()
  })
  return {
    clear: () => { roomActive = false; pendingPreviews.clear(); capturingPreviews.clear(); activePreviewId = null; activePreviewPublication = null; previewing.clear(); voicePlayback.clear(); viewer.clear() },
    refresh,
    participants: participantCards,
    remoteVoices: voicePlayback,
    setDeafened: (deafened) => { voicePlayback.setDeafened(deafened); viewer.setDeafened(deafened) },
    subscribeScreenThumbnails,
    subscribeMicrophones,
    viewer,
  }
}
