import { describe, expect, it, vi } from 'vitest'

import { StreamStartChime } from './stream_start_chime'

describe('screen start sound', () => {
  it('restores the saved off switch without creating browser audio', () => {
    const createContext = vi.fn(() => null)
    const chime = new StreamStartChime(createContext, { getItem: () => 'off', setItem: vi.fn() })
    expect(chime.enabled.value).toBe(false)
    chime.activate()
    expect(createContext).not.toHaveBeenCalled()
  })

  it('does not interrupt voice admission when browser audio is unavailable', () => {
    const chime = new StreamStartChime(() => { throw new Error('audio unavailable') }, null)
    expect(() => chime.activate()).not.toThrow()
    expect(() => chime.play()).not.toThrow()
  })

  it('can be disabled and never plays without an active audio context', () => {
    const oscillator = { connect: vi.fn(), disconnect: vi.fn(), frequency: { value: 0 }, start: vi.fn(), stop: vi.fn(), onended: null as (() => void) | null }
    const gain = { connect: vi.fn(), disconnect: vi.fn(), gain: { setValueAtTime: vi.fn(), exponentialRampToValueAtTime: vi.fn() } }
    const context = { state: 'suspended', currentTime: 1, destination: {}, createOscillator: () => oscillator, createGain: () => gain, resume: vi.fn().mockResolvedValue(undefined) }
    const storage = { getItem: vi.fn(() => null), setItem: vi.fn() }
    const chime = new StreamStartChime(() => context as never, storage)

    chime.play()
    expect(oscillator.start).not.toHaveBeenCalled()
    chime.setEnabled(false)
    context.state = 'running'
    chime.play()
    expect(oscillator.start).not.toHaveBeenCalled()
    expect(storage.setItem).toHaveBeenCalledWith('voice-screen-start-sound:v1', 'off')

    chime.setEnabled(true)
    context.state = 'suspended'
    chime.activate()
    context.state = 'running'
    chime.play()
    expect(context.resume).toHaveBeenCalledOnce()
    expect(oscillator.start).toHaveBeenCalledOnce()
    expect(oscillator.stop).toHaveBeenCalledOnce()
    oscillator.onended?.()
    expect(oscillator.disconnect).toHaveBeenCalledOnce()
    expect(gain.disconnect).toHaveBeenCalledOnce()
  })
})
