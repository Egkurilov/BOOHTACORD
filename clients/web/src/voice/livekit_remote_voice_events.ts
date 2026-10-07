import type {
  LiveKitScreenSources,
  LiveKitScreenViewerEvents,
  LiveKitScreenViewerRoom,
  RemoteVoicePlaybackController,
} from './livekit_screen_viewer_adapter'
import type { LiveKitRemoteParticipant } from './livekit_remote_participants'
import type { RemoteVoiceTrack } from './remote_voice_playback'
import type { ScreenViewerPublication } from './screen_viewer_controller'

export function bindLiveKitRemoteVoiceEvents(
  room: LiveKitScreenViewerRoom,
  events: LiveKitScreenViewerEvents,
  sources: LiveKitScreenSources,
  voicePlayback: RemoteVoicePlaybackController,
  participantId: (participant: LiveKitRemoteParticipant) => string,
  accountId: (participant: LiveKitRemoteParticipant) => string | null,
  refresh: () => void,
): void {
  room.on(events.activeSpeakersChanged, (speakers: LiveKitRemoteParticipant[]) => {
    const active = new Set(speakers.map(participantId))
    const local = room.localParticipant
    if (local) voicePlayback.setSpeaking(participantId(local), active.has(participantId(local)))
    room.remoteParticipants.forEach((participant) => voicePlayback.setSpeaking(participantId(participant), active.has(participantId(participant))))
  })
  room.on(events.trackPublished, (publication: ScreenViewerPublication & { source?: unknown }) => {
    if (publication.source === sources.microphone) publication.setSubscribed?.(true)
    refresh()
  })
  const refreshTrackState = (publication: { source?: unknown }) => {
    if ([sources.microphone, sources.screenAudio, sources.screenVideo].includes(publication.source)) refresh()
  }
  room.on(events.trackMuted, refreshTrackState)
  room.on(events.trackUnmuted, refreshTrackState)
  room.on(events.trackSubscribed, (track: RemoteVoiceTrack, publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.microphone) voicePlayback.attach(participantId(participant), track, participant.name, accountId(participant))
    refresh()
  })
  room.on(events.trackUnsubscribed, (_track: unknown, publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.microphone) voicePlayback.detach(participantId(participant))
    refresh()
  })
}
