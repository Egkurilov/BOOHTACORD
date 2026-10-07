import { describe, expect, it } from 'vitest'
import { applyScreenProfile } from './apply'
import { profileTrack } from './fixture'

describe('screen capture profile constraints', () => {
  it('caps capture to the selected dimensions and frame rate without reading sender state', async () => {
    const f = profileTrack(); await applyScreenProfile(f.track, 'P1080_60')
    expect(f.mediaStreamTrack.applyConstraints).toHaveBeenCalledWith({ width: { max: 1920 }, height: { max: 1080 }, frameRate: { max: 60 } })
    expect(f.mediaStreamTrack.contentHint).toBe('motion')
    expect(f.sender.setParameters).not.toHaveBeenCalled()
  })
  it('keeps portrait dimensions proportional and never requests an upscale', async () => {
    const f = profileTrack(); f.setSettings({ width: 1440, height: 2560, frameRate: 60 })
    await applyScreenProfile(f.track, 'P1080_30')
    expect(f.mediaStreamTrack.contentHint).toBe('text')
    expect(f.mediaStreamTrack.applyConstraints).toHaveBeenCalledWith({ width: { max: 1080 }, height: { max: 1920 }, frameRate: { max: 30 } })
  })
  it('aborts when capture identity changes while constraints are pending', async () => {
    const f = profileTrack(); let current = true
    f.mediaStreamTrack.applyConstraints.mockImplementation(async () => { current = false })
    await expect(applyScreenProfile(f.track, 'P1080_60', () => current)).rejects.toMatchObject({ name: 'AbortError' })
    expect(f.sender.setParameters).not.toHaveBeenCalled()
  })
  it('raises capture limits on upgrade and propagates browser constraint errors', async () => {
    const f = profileTrack(); await applyScreenProfile(f.track, 'P720_30'); await applyScreenProfile(f.track, 'P1440_60')
    expect(f.mediaStreamTrack.contentHint).toBe('motion')
    expect(f.mediaStreamTrack.applyConstraints).toHaveBeenLastCalledWith({ width: { max: 2560 }, height: { max: 1440 }, frameRate: { max: 60 } })
    f.mediaStreamTrack.applyConstraints.mockRejectedValue(new Error('unavailable'))
    await expect(applyScreenProfile(f.track, 'P1080_60')).rejects.toThrow('unavailable')
  })
})
