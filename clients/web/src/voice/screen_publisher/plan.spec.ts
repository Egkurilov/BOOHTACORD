import { describe, expect, it } from 'vitest'
import { screenCapturePlan, screenPublishPlan } from './plan'

describe('screen publication plan', () => {
  it('starts a 1080p60 motion share with explicit two-layer VP8 encodings', () => {
    expect(screenCapturePlan('P1080_60')).toEqual({ audio: true, contentHint: 'motion', resolution: { width: 1920, height: 1080, frameRate: 60 } })
    expect(screenPublishPlan('P1080_60')).toMatchObject({ name: 'screenshare-1080p-60fps', videoCodec: 'vp8', simulcast: true,
      screenShareSimulcastLayers: [{ width: 960, height: 540, encoding: { maxBitrate: 500_000, maxFramerate: 15, priority: 'medium' } }],
      degradationPreference: 'maintain-framerate', screenShareEncoding: { maxBitrate: 8_000_000, maxFramerate: 60, priority: 'medium' } })
  })

  it('keeps text shares resolution-prioritized and derives bitrate from the catalog', () => {
    expect(screenCapturePlan('P1080_30').contentHint).toBe('text')
    expect(screenPublishPlan('P1080_30')).toMatchObject({ simulcast: true, screenShareSimulcastLayers: [{ encoding: { maxBitrate: 625_000, maxFramerate: 15 } }], degradationPreference: 'maintain-resolution', screenShareEncoding: { maxBitrate: 5_000_000, maxFramerate: 30 } })
  })
})
