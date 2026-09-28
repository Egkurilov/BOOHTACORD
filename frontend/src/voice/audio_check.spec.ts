import { describe, expect, it, vi } from 'vitest'

import { levelFromSamples, playSpeakerCheck, startMicrophoneCheck } from './audio_check'

describe('local sound check', () => {
  it('reports silence and bounded microphone level without storing samples', () => {
    expect(levelFromSamples(new Uint8Array([128, 128, 128]))).toBe(0)
    expect(levelFromSamples(new Uint8Array([0, 255]))).toBeGreaterThan(90)
  })

  it('uses the chosen input only on explicit action and releases tracks and context', async () => {
    const stop = vi.fn()
    const stream = { getTracks: () => [{ stop }] } as unknown as MediaStream
    const getUserMedia = vi.fn().mockResolvedValue(stream)
    const analyser = { fftSize: 0, getByteTimeDomainData: (samples: Uint8Array) => samples.fill(128) }
    const close = vi.fn().mockResolvedValue(undefined)
    const context = { createMediaStreamSource: () => ({ connect: vi.fn(), disconnect: vi.fn() }), createAnalyser: () => analyser, close } as unknown as AudioContext
    const check = await startMicrophoneCheck('mic-2', { getUserMedia } as unknown as MediaDevices, () => context)
    expect(getUserMedia).toHaveBeenCalledWith({ audio: { deviceId: { exact: 'mic-2' } }, video: false })
    expect(check.level()).toBe(0)
    await check.stop()
    expect(stop).toHaveBeenCalledOnce()
    expect(close).toHaveBeenCalledOnce()
  })

  it('releases the granted microphone if the audio graph cannot be created', async () => {
    const stop = vi.fn()
    const close = vi.fn().mockResolvedValue(undefined)
    const devices = { getUserMedia: vi.fn().mockResolvedValue({ getTracks: () => [{ stop }] }) } as unknown as MediaDevices
    const context = { createMediaStreamSource: () => { throw new Error('graph unavailable') }, close } as unknown as AudioContext
    await expect(startMicrophoneCheck('default', devices, () => context)).rejects.toThrow('graph unavailable')
    expect(stop).toHaveBeenCalledOnce()
    expect(close).toHaveBeenCalledOnce()
  })

  it('starts the test tone before playback and releases output if playback fails', async () => {
    const start = vi.fn()
    const stop = vi.fn()
    const pause = vi.fn()
    const close = vi.fn().mockResolvedValue(undefined)
    const play = vi.fn().mockImplementation(async () => {
      expect(start).toHaveBeenCalledOnce()
      throw new Error('playback blocked')
    })
    vi.stubGlobal('AudioContext', class {
      createMediaStreamDestination() { return { stream: {} } }
      createOscillator() { return { frequency: { value: 0 }, connect: (gain: unknown) => gain, start, stop } }
      createGain() { return { gain: { value: 0 }, connect: vi.fn() } }
      resume() { return Promise.resolve() }
      close = close
    })
    vi.stubGlobal('Audio', class { srcObject: unknown = null; play = play; pause = pause })
    try {
      await expect(playSpeakerCheck('default')).rejects.toThrow('playback blocked')
      expect(stop).toHaveBeenCalledOnce()
      expect(pause).toHaveBeenCalledOnce()
      expect(close).toHaveBeenCalledOnce()
    } finally {
      vi.unstubAllGlobals()
    }
  })
})
