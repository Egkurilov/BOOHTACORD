import { afterEach, describe, expect, it, vi } from 'vitest'
import { screenCapturePlan, screenPublishPlan } from './plan'
import { selectScreenVideoCodec } from './codec_policy'

afterEach(() => vi.unstubAllEnvs())

describe('screen publication plan', () => {
  it('uses the single-layer baseline unless bounded simulcast is explicitly enabled', () => {
    vi.stubEnv('VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', '')
    const plan = screenPublishPlan('P1080_60')
    expect(plan).toMatchObject({ simulcast: false, screenShareEncoding: { maxBitrate: 8_000_000, maxFramerate: 60 } })
    expect(plan.screenShareSimulcastLayers).toBeUndefined()
  })

  it('starts a 1080p60 motion share with bounded two-layer VP8 encodings only when opted in', () => {
    vi.stubEnv('VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', 'true')
    expect(screenCapturePlan('P1080_60')).toEqual({
      audio: true, contentHint: 'motion', resolution: { width: 1920, height: 1080, frameRate: 60 },
    })
    expect(screenPublishPlan('P1080_60')).toMatchObject({
      name: 'screenshare-1080p-60fps', videoCodec: 'vp8', simulcast: true,
      screenShareSimulcastLayers: [{
        width: 960, height: 540,
        encoding: { maxBitrate: 500_000, maxFramerate: 15, priority: 'medium' },
      }],
      degradationPreference: 'maintain-framerate',
      screenShareEncoding: { maxBitrate: 8_000_000, maxFramerate: 60, priority: 'medium' },
    })
  })

  it('keeps text shares resolution-prioritized and derives bitrate from the catalog', () => {
    vi.stubEnv('VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', 'true')
    expect(screenCapturePlan('P1080_30').contentHint).toBe('text')
    expect(screenPublishPlan('P1080_30')).toMatchObject({
      simulcast: true,
      screenShareSimulcastLayers: [{ encoding: { maxBitrate: 625_000, maxFramerate: 15 } }],
      degradationPreference: 'maintain-resolution',
      screenShareEncoding: { maxBitrate: 5_000_000, maxFramerate: 30 },
    })
  })

  it('keeps VP8 as the explicit default when browser capabilities are unknown', () => {
    expect(selectScreenVideoCodec(undefined)).toEqual({
      outcome: 'unknown', codec: 'vp8', reason: 'capabilities-unavailable',
    })
    expect(screenPublishPlan('P1080_30', null)).toMatchObject({ videoCodec: 'vp8' })
  })

  it('uses VP8 when the browser reports support and H.264 only as a known fallback', () => {
    expect(selectScreenVideoCodec([{ mimeType: 'video/VP8' }, { mimeType: 'video/H264' }])).toEqual({
      outcome: 'selected', codec: 'vp8', reason: 'preferred-supported',
    })
    expect(selectScreenVideoCodec([{ mimeType: 'video/H264' }])).toEqual({
      outcome: 'selected', codec: 'h264', reason: 'compatibility-fallback',
    })
    expect(screenPublishPlan('P1080_30', [{ mimeType: 'video/H264' }])).toMatchObject({ videoCodec: 'h264' })
  })

  it('returns an explicit unsupported decision instead of selecting an unadvertised codec', () => {
    expect(selectScreenVideoCodec([{ mimeType: 'video/VP9' }])).toEqual({
      outcome: 'unsupported', reason: 'no-supported-codec',
    })
    expect(() => screenPublishPlan('P1080_30', [{ mimeType: 'video/VP9' }])).toThrow('No supported screen-sharing video codec')
  })
})
