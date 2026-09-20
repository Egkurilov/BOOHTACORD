import { describe, expect, it, vi } from 'vitest'

import { AudioMixer } from './audio_gain'

function element() {
  return { muted: false, volume: 1 } as HTMLAudioElement
}

describe('audio gain', () => {
  it('uses a Web Audio gain node for volumes over the HTML media element limit', () => {
    const gain = { connect: vi.fn(), disconnect: vi.fn(), gain: { value: 1 } }
    const source = { connect: vi.fn(), disconnect: vi.fn() }
    const context = { createGain: vi.fn(() => gain), createMediaElementSource: vi.fn(() => source), destination: {} }
    const output = new AudioMixer(() => context as never).attach(element())

    output.setVolume(200)
    output.setMuted(true)
    output.setMuted(false)
    output.dispose()

    expect(source.connect).toHaveBeenCalledWith(gain)
    expect(gain.connect).toHaveBeenCalledWith(context.destination)
    expect(gain.gain.value).toBe(2)
    expect(source.disconnect).toHaveBeenCalledOnce()
    expect(gain.disconnect).toHaveBeenCalledOnce()
  })

  it('keeps a truthful capped fallback when Web Audio is unavailable', () => {
    const audio = element()
    const output = new AudioMixer(() => null).attach(audio)

    output.setVolume(200)
    expect(audio.volume).toBe(1)
    output.setVolume(50)
    output.setMuted(true)

    expect(audio.volume).toBe(0.5)
    expect(audio.muted).toBe(true)
  })
})
