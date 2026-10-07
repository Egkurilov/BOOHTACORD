import { describe, expect, it, vi } from 'vitest'

import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'

const events = {
  activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
}

describe('screen publication subscriptions', () => {
  it('keeps 20 publications discoverable without subscribing until one is selected', () => {
    const participants = Array.from({ length: 20 }, (_, index) => {
      const video = { isMuted: false, setSubscribed: vi.fn(), source: 'screen-video' }
      const audio = { isMuted: false, setSubscribed: vi.fn(), source: 'screen-audio' }
      return {
        audio, identity: `screen-${index}`, name: `Screen ${index}`, video,
        getTrackPublication: (source: string) => source === 'screen-video' ? video : source === 'screen-audio' ? audio : undefined,
      }
    })
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map(participants.map((participant) => [participant.identity, participant])),
    }
    const binding = bindLiveKitScreenViewer(room, events, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    binding.refresh()
    for (const participant of participants) {
      listeners.get('track-published')!(participant.video, participant)
      listeners.get('track-unmuted')!(participant.video, participant)
    }

    expect(binding.viewer.cards()).toHaveLength(20)
    expect(binding.viewer.cards().every((card) => card.thumbnailUrl === undefined)).toBe(true)
    for (const participant of participants) {
      expect(participant.video.setSubscribed).not.toHaveBeenCalledWith(true)
      expect(participant.audio.setSubscribed).not.toHaveBeenCalledWith(true)
    }

    binding.viewer.select('screen-7:screen', null, null)
    expect(participants[7]!.video.setSubscribed).toHaveBeenLastCalledWith(true)
    expect(participants[7]!.audio.setSubscribed).toHaveBeenLastCalledWith(true)
    for (const [index, participant] of participants.entries()) {
      if (index === 7) continue
      expect(participant.video.setSubscribed).not.toHaveBeenCalledWith(true)
      expect(participant.audio.setSubscribed).not.toHaveBeenCalledWith(true)
    }
  })
})
