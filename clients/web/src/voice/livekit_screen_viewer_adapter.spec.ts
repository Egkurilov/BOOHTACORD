import { describe, expect, it, vi } from 'vitest'

import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'
import type { RemoteVoiceTrack } from './remote_voice_playback'

function publication(source?: string) {
  return { isMuted: false, setSubscribed: vi.fn(), source }
}

describe('LiveKit screen viewer adapter', () => {
  it('subscribes to room voice while keeping every unselected screen track disabled', () => {
    const microphone = publication('microphone')
    const video = publication('screen-video')
    const audio = publication('screen-audio')
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', {
        identity: 'alice',
        metadata: 'account:22222222-2222-4222-8222-222222222222',
        name: 'Alice',
        getTrackPublication: (source: string) => source === 'microphone' ? microphone : source === 'screen-video' ? video : source === 'screen-audio' ? audio : undefined,
      }]]),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })

    binding.subscribeMicrophones()
    binding.refresh()
    listeners.get('track-published')!(microphone)

    expect(microphone.setSubscribed).toHaveBeenCalledWith(true)
    expect(video.setSubscribed).toHaveBeenCalledWith(false)
    expect(audio.setSubscribed).toHaveBeenCalledWith(false)
    expect(binding.viewer.cards()).toEqual([{ accountId: '22222222-2222-4222-8222-222222222222', hasAudio: true, id: '22222222-2222-4222-8222-222222222222:screen', participantId: '22222222-2222-4222-8222-222222222222', participantName: 'Alice' }])
    expect(binding.participants.cards()[0]?.microphoneMuted).toBe(false)
    microphone.isMuted = true
    listeners.get('track-muted')!(microphone)
    expect(binding.participants.cards()[0]?.microphoneMuted).toBe(true)
    microphone.isMuted = false
    listeners.get('track-unmuted')!(microphone)
    expect(binding.participants.cards()[0]?.microphoneMuted).toBe(false)
  })

  it('owns remote microphone playback and includes it in deafen cleanup', () => {
    const microphone = publication('microphone')
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const alice = { identity: 'voice-lease:lease-1', metadata: 'account:11111111-1111-4111-8111-111111111111', getTrackPublication: () => microphone }
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice]]),
    }
    const playback = { attach: vi.fn(), cards: () => [], clear: vi.fn(), detach: vi.fn(), forget: vi.fn(), isSpeaking: () => false, onChange: () => () => undefined, setDeafened: vi.fn(), setSpeaking: vi.fn(), setVolume: vi.fn() }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' }, playback)
    const track = {} as RemoteVoiceTrack

    listeners.get('track-subscribed')!(track, microphone, alice)
    binding.setDeafened(true)
    listeners.get('track-unsubscribed')!(track, microphone, alice)
    binding.clear()

    expect(playback.attach).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111', track, undefined, '11111111-1111-4111-8111-111111111111')
    expect(playback.setDeafened).toHaveBeenCalledWith(true)
    expect(playback.detach).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111')
    expect(playback.clear).toHaveBeenCalledOnce()
  })

  it('temporarily subscribes to a screen track for one thumbnail then lets the viewer unsubscribe it', async () => {
    const track = { attach: vi.fn(), detach: vi.fn() }
    const video = { isMuted: false, setSubscribed: vi.fn(), source: 'screen-video', track: undefined as typeof track | undefined }
    const alice = {
      identity: 'alice',
      metadata: 'account:22222222-2222-4222-8222-222222222222',
      getTrackPublication: (source: string) => source === 'screen-video' ? video : undefined,
    }
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice]]),
    }
    let finishCapture!: (captured: boolean) => void
    const capture = vi.fn((
      _track: unknown,
      onThumbnail: (bytes: Uint8Array) => void,
    ) => new Promise<boolean>((resolve) => {
      finishCapture = (captured) => {
        if (captured) onThumbnail(Uint8Array.from([0xff, 0xd8, 0x01, 0xff, 0xd9]))
        resolve(captured)
      }
    }))
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' }, undefined, capture as never)
    listeners.get('track-published')!(video, alice)
    video.track = track
    listeners.get('track-subscribed')!(track, video, alice)
    await Promise.resolve()

    expect(video.setSubscribed).toHaveBeenLastCalledWith(true)
    expect(capture).toHaveBeenCalledOnce()
    expect(video.setSubscribed).not.toHaveBeenCalledWith(false)

    finishCapture(true)
    await vi.waitFor(() => expect(video.setSubscribed).toHaveBeenLastCalledWith(false))
  })

  it('keeps the track subscribed when the viewer selects it during thumbnail capture', async () => {
    const track = { attach: vi.fn(), detach: vi.fn() }
    const video = { isMuted: false, setSubscribed: vi.fn(), source: 'screen-video', track: undefined as typeof track | undefined }
    const alice = {
      identity: 'alice',
      metadata: 'account:22222222-2222-4222-8222-222222222222',
      getTrackPublication: (source: string) => source === 'screen-video' ? video : undefined,
    }
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice]]),
    }
    let finishCapture!: (captured: boolean) => void
    const capture = vi.fn((
      _track: unknown,
      onThumbnail: (bytes: Uint8Array) => void,
    ) => new Promise<boolean>((resolve) => {
      finishCapture = (captured) => {
        if (captured) onThumbnail(Uint8Array.from([0xff, 0xd8, 0x01, 0xff, 0xd9]))
        resolve(captured)
      }
    }))
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' }, undefined, capture as never)

    listeners.get('track-published')!(video, alice)
    video.track = track
    listeners.get('track-subscribed')!(track, video, alice)
    await Promise.resolve()
    binding.viewer.select('22222222-2222-4222-8222-222222222222:screen', null, null)
    let viewerChanges = 0
    binding.viewer.onChange(() => { viewerChanges++ })

    finishCapture(true)
    await vi.waitFor(() => expect(viewerChanges).toBeGreaterThan(1))

    expect(video.setSubscribed).toHaveBeenLastCalledWith(true)
    expect(video.setSubscribed).not.toHaveBeenCalledWith(false)
  })

  it('serializes temporary preview subscriptions across simultaneous screen shares', async () => {
    const track = { attach: vi.fn(), detach: vi.fn() }
    const first = { ...publication('screen-video'), track: undefined as typeof track | undefined }
    const second = publication('screen-video')
    const alice = { identity: 'alice', getTrackPublication: () => first }
    const bob = { identity: 'bob', getTrackPublication: () => second }
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice], ['bob', bob]]),
    }
    let finishCapture!: (captured: boolean) => void
    const capture = vi.fn(() => new Promise<boolean>((resolve) => { finishCapture = resolve }))
    bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' }, undefined, capture as never).subscribeScreenThumbnails()
    expect(first.setSubscribed).toHaveBeenLastCalledWith(true)
    expect(second.setSubscribed).not.toHaveBeenCalledWith(true)
    first.track = track
    listeners.get('track-subscribed')!(track, first, alice)
    await Promise.resolve()
    finishCapture(true)
    await vi.waitFor(() => {
      expect(first.setSubscribed).toHaveBeenLastCalledWith(false)
      expect(second.setSubscribed).toHaveBeenLastCalledWith(true)
    })
    expect(capture).toHaveBeenCalledOnce()
  })

  it('does not create a preview subscription for the screen already selected by the viewer', () => {
    const video = publication('screen-video')
    const alice = { identity: 'alice', metadata: 'account:22222222-2222-4222-8222-222222222222', getTrackPublication: () => video }
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice]]),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    binding.refresh()
    binding.viewer.select('22222222-2222-4222-8222-222222222222:screen', null, null)
    video.setSubscribed.mockClear()

    binding.subscribeScreenThumbnails()

    expect(video.setSubscribed).not.toHaveBeenCalled()
  })

  it('retains a captured preview after unsubscribe and clears it only when the share is unpublished', () => {
    const video = publication('screen-video')
    const alice = { identity: 'alice', metadata: 'account:22222222-2222-4222-8222-222222222222', getTrackPublication: () => video }
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice]]),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    const removeThumbnail = vi.spyOn(binding.viewer, 'removeThumbnail')

    listeners.get('track-unsubscribed')!({}, video, alice)
    expect(removeThumbnail).not.toHaveBeenCalled()
    listeners.get('track-unpublished')!(video, alice)
    expect(removeThumbnail).toHaveBeenCalledWith('22222222-2222-4222-8222-222222222222')
  })

  it('maps LiveKit active speakers to local and remote participants and forgets a departed participant', () => {
    const microphone = publication('microphone')
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const alice = { identity: 'lease-a', metadata: 'account:11111111-1111-4111-8111-111111111111', getTrackPublication: () => microphone }
    const bob = { identity: 'lease-b', metadata: 'account:22222222-2222-4222-8222-222222222222', getTrackPublication: () => microphone }
    const local = { identity: 'owner-lease', metadata: 'account:33333333-3333-4333-8333-333333333333', getTrackPublication: () => microphone }
    const room: LiveKitScreenViewerRoom = {
      localParticipant: local,
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice], ['bob', bob]]),
    }
    const playback = { attach: vi.fn(), cards: () => [], clear: vi.fn(), detach: vi.fn(), forget: vi.fn(), isSpeaking: () => false, onChange: () => () => undefined, setDeafened: vi.fn(), setSpeaking: vi.fn(), setVolume: vi.fn() }
    bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' }, playback)

    listeners.get('active-speakers-changed')!([alice, local])
    listeners.get('participant-disconnected')!(alice)

    expect(playback.setSpeaking).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111', true)
    expect(playback.setSpeaking).toHaveBeenCalledWith('22222222-2222-4222-8222-222222222222', false)
    expect(playback.setSpeaking).toHaveBeenCalledWith('33333333-3333-4333-8333-333333333333', true)
    expect(playback.forget).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111')
  })

})
