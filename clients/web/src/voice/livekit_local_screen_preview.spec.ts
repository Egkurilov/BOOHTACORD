import { describe, expect, it, vi } from 'vitest'

import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'

describe('LiveKit local screen preview', () => {
  it('appears on publication, stays silent, and disappears when the owner stops sharing', () => {
    const videoTrack = { attach: vi.fn(), detach: vi.fn() }
    let localVideo: { track: typeof videoTrack } | undefined
    const getLocalPublication = vi.fn((source: string) => source === 'screen-video' ? localVideo : undefined)
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      localParticipant: { identity: 'local-lease', metadata: 'account:33333333-3333-4333-8333-333333333333', getTrackPublication: getLocalPublication },
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map(),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })

    binding.refresh()
    expect(binding.viewer.cards()).toEqual([])
    localVideo = { track: videoTrack }
    listeners.get('local-track-published')!({ source: 'screen-video' })
    expect(binding.viewer.cards()).toEqual([{
      accountId: '33333333-3333-4333-8333-333333333333', hasAudio: false, id: 'local:33333333-3333-4333-8333-333333333333:screen', isLocal: true,
      participantId: '33333333-3333-4333-8333-333333333333', participantName: 'Ваш экран', profileSource: 'unknown',
    }])
    expect(getLocalPublication).toHaveBeenCalledWith('screen-video')
    expect(getLocalPublication).not.toHaveBeenCalledWith('screen-audio')
    localVideo = undefined
    listeners.get('local-track-unpublished')!()
    expect(binding.viewer.cards()).toEqual([])
  })
})
