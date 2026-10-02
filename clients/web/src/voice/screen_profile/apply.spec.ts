import { describe, expect, it, vi } from 'vitest'
import { applyScreenProfile } from './apply'
import { profileTrack } from './fixture'

describe('selected screen profile', () => {
  it('caps capture at 1080p60 and preserves disabled simulcast layers', async () => {
    const f = profileTrack()
    await applyScreenProfile(f.track, 'P1080_60')
    expect(f.mediaStreamTrack.applyConstraints).toHaveBeenCalledWith({ width: { max: 1920 }, height: { max: 1080 }, frameRate: { max: 60 } })
    expect(f.sender.getParameters().encodings).toEqual([
      { rid: 'h', scaleResolutionDownBy: 1, maxBitrate: 8_000_000, maxFramerate: 60 },
      { rid: 'l', scaleResolutionDownBy: 2, active: false, maxBitrate: 2_000_000, maxFramerate: 60 },
    ])
  })
  it('bounds portrait capture proportionally and never upscales a small source', async () => {
    const f = profileTrack()
    f.setSettings({ width: 1440, height: 2560, frameRate: 60 })
    await applyScreenProfile(f.track, 'P1080_30')
    expect(f.mediaStreamTrack.getSettings()).toEqual({ width: 1080, height: 1920, frameRate: 30 })
    f.setSettings({ width: 640, height: 360, frameRate: 30 })
    await applyScreenProfile(f.track, 'P1080_30')
    expect(f.sender.getParameters().encodings[0]!.scaleResolutionDownBy).toBe(1)
  })
  it('scales encoded output even if capture ignores maximum dimensions', async () => {
    const f = profileTrack()
    f.mediaStreamTrack.applyConstraints.mockImplementation(async () => {})
    await applyScreenProfile(f.track, 'P1080_60')
    expect(f.sender.getParameters().encodings.map(e => e.scaleResolutionDownBy)).toEqual([4 / 3, 8 / 3])
  })
  it('does not write sender parameters after stop or capture replacement', async () => {
    const f = profileTrack()
    let current = true
    f.mediaStreamTrack.applyConstraints.mockImplementation(async () => { current = false })
    await expect(applyScreenProfile(f.track, 'P1080_60', () => current)).rejects.toMatchObject({ name: 'AbortError' })
    expect(f.sender.setParameters).not.toHaveBeenCalled()
  })
  it('raises capture limits on an explicit quality upgrade and propagates capture errors', async () => {
    const f = profileTrack()
    await applyScreenProfile(f.track, 'P720_30')
    await applyScreenProfile(f.track, 'P1440_60')
    expect(f.mediaStreamTrack.applyConstraints).toHaveBeenLastCalledWith({ width: { max: 2560 }, height: { max: 1440 }, frameRate: { max: 60 } })
    f.mediaStreamTrack.applyConstraints.mockRejectedValue(new Error('unavailable'))
    await expect(applyScreenProfile(f.track, 'P1080_60')).rejects.toThrow('unavailable')
  })
})
