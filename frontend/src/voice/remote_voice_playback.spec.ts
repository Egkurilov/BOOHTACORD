import { describe, expect, it, vi } from 'vitest'

import { RemoteVoicePlayback, type RemoteVoiceTrack } from './remote_voice_playback'

function audioElement() {
  return { autoplay: false, muted: false, remove: vi.fn() } as unknown as HTMLAudioElement
}

describe('remote voice playback', () => {
  it('mutes attached and future remote microphone elements while deafened', () => {
    const first = audioElement()
    const second = audioElement()
    const elements = [first, second]
    const append = vi.fn()
    const track: RemoteVoiceTrack = { attach: vi.fn(), detach: vi.fn() }
    const playback = new RemoteVoicePlayback(() => elements.shift()!, append)

    playback.attach('alice', track)
    playback.setDeafened(true)
    playback.attach('bob', track)

    expect(first.autoplay).toBe(true)
    expect(first.muted).toBe(true)
    expect(second.muted).toBe(true)
    expect(append).toHaveBeenCalledTimes(2)
  })

  it('detaches and removes owned audio on participant leave and clear', () => {
    const first = audioElement()
    const second = audioElement()
    const elements = [first, second]
    const track: RemoteVoiceTrack = { attach: vi.fn(), detach: vi.fn() }
    const playback = new RemoteVoicePlayback(() => elements.shift()!, vi.fn())

    playback.attach('alice', track)
    playback.attach('bob', track)
    playback.detach('alice')
    playback.clear()

    expect(track.detach).toHaveBeenCalledWith(first)
    expect(track.detach).toHaveBeenCalledWith(second)
    expect(first.remove).toHaveBeenCalledOnce()
    expect(second.remove).toHaveBeenCalledOnce()
  })

  it('preserves a participant level for a later track and disposes its gain handle', () => {
    const output = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const track: RemoteVoiceTrack = { attach: vi.fn(), detach: vi.fn() }
    const playback = new RemoteVoicePlayback(audioElement, vi.fn(), { attach: vi.fn(() => output) } as never)

    playback.setVolume('alice', 175)
    playback.attach('alice', track)
    playback.setDeafened(true)
    playback.detach('alice')

    expect(output.setVolume).toHaveBeenCalledWith(175)
    expect(output.setMuted).toHaveBeenCalledWith(true)
    expect(output.dispose).toHaveBeenCalledOnce()
  })

  it('retains speaking state until a late audio attach and removes it when the participant leaves', () => {
    const track: RemoteVoiceTrack = { attach: vi.fn(), detach: vi.fn() }
    const playback = new RemoteVoicePlayback(audioElement, vi.fn())

    playback.setSpeaking('alice', true)
    playback.attach('alice', track, 'Alice')

    expect(playback.cards()).toEqual([expect.objectContaining({ id: 'alice', speaking: true })])
    playback.forget('alice')
    expect(playback.cards()).toEqual([])
  })

  it('notifies listeners when the local participant speaking state changes without an attached track', () => {
    const playback = new RemoteVoicePlayback(audioElement, vi.fn())
    const changed = vi.fn()
    playback.onChange(changed)

    playback.setSpeaking('owner-account', true)
    playback.setSpeaking('owner-account', false)

    expect(playback.isSpeaking('owner-account')).toBe(false)
    expect(changed).toHaveBeenCalledTimes(2)
  })
})
