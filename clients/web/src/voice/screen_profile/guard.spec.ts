import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ScreenProfileGuard } from './guard'
import { profileTrack } from './fixture'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())
async function tick(guard: ScreenProfileGuard) { await vi.advanceTimersByTimeAsync(5000); await guard.check() }
function removeCaps(f: ReturnType<typeof profileTrack>) { f.setParameters({ encodings: [{ rid: 'h' }] } as RTCRtpSendParameters) }

describe('screen profile guard', () => {
  it('confirms drift three times, repairs once, then verifies the repair', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    await guard.apply('P1080_60')
    removeCaps(f)
    await tick(guard); await guard.check(); await tick(guard)
    expect(f.sender.setParameters).toHaveBeenCalledTimes(1)
    await tick(guard)
    expect(f.sender.setParameters).toHaveBeenCalledTimes(2)
    expect(guard.snapshot).toMatchObject({ status: 'repairing', attempts: 1 })
    await tick(guard)
    expect(guard.snapshot).toMatchObject({ status: 'matched', attempts: 1 })
    removeCaps(f)
    await tick(guard); await tick(guard); await tick(guard); await tick(guard)
    expect(f.sender.setParameters).toHaveBeenCalledTimes(2)
    expect(guard.snapshot?.status).toBe('failed')
  })
  it('uses the current selected profile and resets the repair budget for explicit changes', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    await guard.apply('P1080_60'); await guard.apply('P720_30')
    await tick(guard)
    expect(guard.snapshot).toMatchObject({ status: 'matched', attempts: 0, captureHeight: 720, captureFps: 30 })
    expect(f.sender.getParameters().encodings[0]!.maxFramerate).toBe(30)
  })
  it('does not force lower resolution or FPS back up during adaptation', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    await guard.apply('P1080_60')
    f.sender.getStats.mockImplementation(async () => new Map([['v', { id: 'v', type: 'outbound-rtp', kind: 'video', rid: 'h', framesPerSecond: 10, frameWidth: 640, frameHeight: 360, qualityLimitationReason: 'bandwidth' }]]) as unknown as RTCStatsReport)
    for (let n = 0; n < 6; n++) await tick(guard)
    expect(guard.snapshot?.status).toBe('adapted')
    expect(f.sender.setParameters).toHaveBeenCalledTimes(1)
  })
  it('ignores inactive layers and missing stats without inventing measurements', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    await guard.apply('P1080_60')
    f.setParameters({ encodings: [{ active: false }] } as RTCRtpSendParameters)
    for (let n = 0; n < 5; n++) await tick(guard)
    expect(guard.snapshot?.status).toBe('inactive')
    expect(f.sender.setParameters).toHaveBeenCalledTimes(1)
    guard.stop()
    await tick(guard)
    expect(guard.snapshot).toBeUndefined()
  })

  it('shows a persistent warning when the sole recovery attempt fails', async () => {
    const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track)
    await guard.apply('P1080_60')
    const validParameters = f.sender.getParameters()
    removeCaps(f)
    f.mediaStreamTrack.applyConstraints.mockRejectedValue(new Error('browser rejected'))
    await tick(guard); await tick(guard); await tick(guard); await tick(guard)
    expect(guard.snapshot).toMatchObject({ status: 'failed', attempts: 1 })
    expect(f.mediaStreamTrack.applyConstraints).toHaveBeenCalledTimes(2)
    f.setParameters(validParameters)
    await tick(guard)
    expect(guard.snapshot).toMatchObject({ status: 'failed', reason: 'configuration', attempts: 1 })
  })
})
