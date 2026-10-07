import { describe, expect, it, vi } from 'vitest'

import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'

const events = {
  activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackSubscriptionFailed: 'track-subscription-failed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
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

  it('ignores a late TrackSubscribed for A after the viewer moved to B', () => {
    const trackA = { attach: vi.fn(), detach: vi.fn() }
    const trackB = { attach: vi.fn(), detach: vi.fn() }
    const videoA = { source: 'screen-video', setSubscribed: vi.fn(), track: trackA }
    const videoB = { source: 'screen-video', setSubscribed: vi.fn(), track: trackB }
    const alice = { identity: 'alice', name: 'Alice', getTrackPublication: (source: string) => source === 'screen-video' ? videoA : undefined }
    const bob = { identity: 'bob', name: 'Bob', getTrackPublication: (source: string) => source === 'screen-video' ? videoB : undefined }
    const listeners = new Map<string, (...args: any[]) => void>()
    const room = {
      on: vi.fn((event: string, listener: (...args: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice], ['bob', bob]]),
    }
    const binding = bindLiveKitScreenViewer(room, events, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    const player = {} as HTMLVideoElement
    binding.refresh()
    binding.viewer.select('alice:screen', player, null)
    binding.viewer.select('bob:screen', player, null)
    const aAttachCount = trackA.attach.mock.calls.length

    listeners.get('track-subscribed')!({}, videoA, alice)

    expect(binding.viewer.selectedId).toBe('bob:screen')
    expect(trackA.attach).toHaveBeenCalledTimes(aAttachCount)
    expect(trackB.attach).toHaveBeenLastCalledWith(player)
    expect(videoA.setSubscribed).toHaveBeenLastCalledWith(false)
    expect(videoB.setSubscribed).toHaveBeenLastCalledWith(true)
  })

  it('shows subscription failure only for the currently selected publication SID', () => {
    const videoA = { source: 'screen-video', trackSid: 'TR_A', setSubscribed: vi.fn() }
    const videoB = { source: 'screen-video', trackSid: 'TR_B', setSubscribed: vi.fn() }
    const alice = { identity: 'alice', name: 'Alice', getTrackPublication: () => videoA }
    const bob = { identity: 'bob', name: 'Bob', getTrackPublication: () => videoB }
    const listeners = new Map<string, (...args: any[]) => void>()
    const room = { on: vi.fn((event: string, listener: (...args: any[]) => void) => listeners.set(event, listener)), remoteParticipants: new Map([['alice', alice], ['bob', bob]]) }
    const binding = bindLiveKitScreenViewer(room, events, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    binding.refresh()
    binding.viewer.select('alice:screen', null, null)
    binding.viewer.select('bob:screen', null, null)

    listeners.get('track-subscription-failed')!('TR_A', alice)
    expect(binding.viewer.subscriptionFailed).toBe(false)
    listeners.get('track-subscription-failed')!('TR_B', bob)
    expect(binding.viewer.subscriptionFailed).toBe(true)
  })

  it('refreshes muted screen state and exposes the source pause without resubscribing', () => {
    const video = { isMuted: false, source: 'screen-video', setSubscribed: vi.fn() }
    const participant = { identity: 'alice', name: 'Alice', getTrackPublication: (source: string) => source === 'screen-video' ? video : undefined }
    const listeners = new Map<string, (...args: any[]) => void>()
    const room = { on: vi.fn((event: string, listener: (...args: any[]) => void) => listeners.set(event, listener)), remoteParticipants: new Map([['alice', participant]]) }
    const binding = bindLiveKitScreenViewer(room, events, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    binding.refresh()
    binding.viewer.select('alice:screen', null, null)
    video.isMuted = true
    listeners.get('track-muted')!(video, participant)

    expect(binding.viewer.cards()[0]?.videoMuted).toBe(true)
    expect(video.setSubscribed).toHaveBeenLastCalledWith(true)
  })
})
