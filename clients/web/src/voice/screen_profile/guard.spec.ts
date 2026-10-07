import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ScreenProfileGuard } from './guard'
import { profileTrack } from './fixture'
import { screenSenderStatsSampler } from '../screen_stats_sampler'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())
async function check(guard: ScreenProfileGuard) { await vi.advanceTimersByTimeAsync(5000); await guard.check() }

describe('screen profile diagnostics', () => {
  it('reports sender drift without repairing or changing sender parameters', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    f.setSettings({ width: 1920, height: 1080, frameRate: 60 }); screenSenderStatsSampler.clear(f.sender)
    guard.adopt('P1080_60'); f.setParameters({ encodings: [{ rid: 'h' }] } as RTCRtpSendParameters)
    await check(guard); await check(guard); await check(guard)
    expect(guard.snapshot).toMatchObject({ status: 'drift', reason: 'configuration', attempts: 0 })
    expect(f.sender.setParameters).not.toHaveBeenCalled()
    guard.stop(); screenSenderStatsSampler.clear(f.sender)
  })
  it('preserves adapted and inactive states as read-only observations', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    f.setSettings({ width: 1920, height: 1080, frameRate: 60 }); f.setParameters({ encodings: [{ rid: 'h', maxFramerate: 60, maxBitrate: 8_000_000, scaleResolutionDownBy: 1 }] } as RTCRtpSendParameters)
    screenSenderStatsSampler.clear(f.sender)
    guard.adopt('P1080_60')
    f.sender.getStats.mockResolvedValue(new Map([['v', { id: 'v', type: 'outbound-rtp', kind: 'video', rid: 'h', framesPerSecond: 10, frameWidth: 640, frameHeight: 360, qualityLimitationReason: 'bandwidth' }]]) as unknown as RTCStatsReport)
    await check(guard); expect(guard.snapshot?.status).toBe('adapted')
    f.setParameters({ encodings: [{ active: false }] } as RTCRtpSendParameters)
    await check(guard); expect(guard.snapshot?.status).toBe('inactive')
    expect(f.sender.setParameters).not.toHaveBeenCalled()
    guard.stop(); screenSenderStatsSampler.clear(f.sender)
  })
  it('adopts an explicit profile change without writing the sender', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    f.setSettings({ width: 1280, height: 720, frameRate: 30 }); f.setParameters({ encodings: [{ rid: 'h', maxFramerate: 30, maxBitrate: 2_500_000, scaleResolutionDownBy: 1 }] } as RTCRtpSendParameters)
    guard.adopt('P720_30'); await check(guard)
    expect(guard.snapshot).toMatchObject({ status: 'matched', attempts: 0, captureHeight: 720, captureFps: 30 })
    expect(f.sender.setParameters).not.toHaveBeenCalled()
    guard.stop(); screenSenderStatsSampler.clear(f.sender)
  })
  it('qualifies drift read-only and permits one explicit managed repair', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    f.setSettings({ width: 1920, height: 1080, frameRate: 60 }); f.setParameters({ encodings: [{ rid: 'h' }] } as RTCRtpSendParameters)
    guard.adopt('P1080_60'); await check(guard); await check(guard); await check(guard)
    expect(guard.snapshot).toMatchObject({ status: 'drift', reason: 'configuration', attempts: 0 })
    const repaired = await guard.repair('P1080_60', async () => {
      f.setParameters({ encodings: [{ rid: 'h', maxFramerate: 60, maxBitrate: 8_000_000, scaleResolutionDownBy: 1 }] } as RTCRtpSendParameters)
    }, () => true)
    expect(repaired).toBe(true); expect(guard.snapshot).toMatchObject({ status: 'checking', attempts: 1 })
    expect(await guard.repair('P1080_60', async () => {}, () => true)).toBe(false)
    expect(f.sender.setParameters).not.toHaveBeenCalled(); guard.stop(); screenSenderStatsSampler.clear(f.sender)
  })
})
