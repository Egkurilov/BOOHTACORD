import { describe, expect, it, vi } from 'vitest'

import { LiveKitScreenRegistry, type ScreenParticipantPublication } from './livekit_screen_registry'

function publication() {
  return { setSubscribed: vi.fn(), name: 'screenshare-1080p-30fps' }
}

function participant(identity: string, video = publication(), audio?: ReturnType<typeof publication>): ScreenParticipantPublication {
  return { audio, identity, name: identity.toUpperCase(), video }
}

describe('LiveKit screen registry', () => {
  it('lists only remote screen-video publications and disables unselected screen tracks', () => {
    const aliceVideo = publication()
    const aliceAudio = publication()
    const bobVideo = publication()
    const registry = new LiveKitScreenRegistry()

    registry.refresh([participant('alice', aliceVideo, aliceAudio), participant('bob', bobVideo)], null)

    expect(registry.streams().map(({ hasAudio, id, participantId, participantName }) => ({ hasAudio, id, participantId, participantName }))).toEqual([
      { hasAudio: true, id: 'alice:screen', participantId: 'alice', participantName: 'ALICE' },
      { hasAudio: false, id: 'bob:screen', participantId: 'bob', participantName: 'BOB' },
    ])
    expect(aliceVideo.setSubscribed).toHaveBeenCalledWith(false)
    expect(aliceAudio.setSubscribed).toHaveBeenCalledWith(false)
    expect(bobVideo.setSubscribed).toHaveBeenCalledWith(false)
  })

  it('does not turn off the currently selected stream while new room events arrive', () => {
    const video = publication()
    const audio = publication()
    const registry = new LiveKitScreenRegistry()

    registry.refresh([participant('alice', video, audio)], 'alice:screen')

    expect(video.setSubscribed).not.toHaveBeenCalled()
    expect(audio.setSubscribed).not.toHaveBeenCalled()
  })

  it('does not display a lease identity when a remote screen has no LiveKit name', () => {
    const registry = new LiveKitScreenRegistry()
    registry.refresh([{ identity: 'voice-lease:secret-lease', video: publication() }], null)
    expect(registry.streams()[0]?.participantName).toBe('Участник')
  })

  it('lists the owner screen as a silent self-preview without subscribing it', () => {
    const localVideo = { track: { attach: vi.fn(), detach: vi.fn() } }
    const registry = new LiveKitScreenRegistry()

    registry.refresh([{ accountId: 'self-account', identity: 'self-account', isLocal: true, name: 'Owner', video: localVideo }], null)

    expect(registry.streams()).toEqual([expect.objectContaining({
      accountId: 'self-account', hasAudio: false, id: 'local:self-account:screen', isLocal: true,
      participantId: 'self-account', participantName: 'Ваш экран', video: localVideo,
    })])
  })

  it('reads the sender target profile from the LiveKit video track name', () => {
    const registry = new LiveKitScreenRegistry()
    registry.refresh([participant('alice')], null)
    expect(registry.streams()[0]?.targetProfile).toBe('1080p · 30 FPS')
  })
})
