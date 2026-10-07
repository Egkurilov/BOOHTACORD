import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { ScreenProfileGuard } from './guard'
import { profileTrack } from './fixture'
import { screenSenderStatsSampler } from '../screen_stats_sampler'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())
function deferred() { let resolve!: (report: RTCStatsReport) => void; const promise = new Promise<RTCStatsReport>(done => { resolve = done }); return { promise, resolve } }

it('discards pending diagnostic stats after explicit profile adoption', async () => {
  const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track), pending = deferred()
  guard.adopt('P1080_60')
  f.sender.getStats.mockImplementationOnce(async () => pending.promise)
  await vi.advanceTimersByTimeAsync(5000); const check = guard.check()
  guard.adopt('P720_30'); pending.resolve(new Map() as unknown as RTCStatsReport); await check
  expect(guard.snapshot).toMatchObject({ status: 'checking', attempts: 0 })
  expect(f.sender.setParameters).not.toHaveBeenCalled()
  guard.stop(); screenSenderStatsSampler.clear(f.sender)
})

it('does not publish stale diagnostics after stop or capture replacement', async () => {
  const old = profileTrack(), replacement = profileTrack(), pending = deferred(); let current = old.track
  const guard = new ScreenProfileGuard(() => current); guard.adopt('P1080_60')
  old.sender.getStats.mockImplementationOnce(async () => pending.promise)
  await vi.advanceTimersByTimeAsync(5000); const check = guard.check()
  current = replacement.track; pending.resolve(new Map() as unknown as RTCStatsReport); await check
  await vi.advanceTimersByTimeAsync(5000); await guard.check()
  expect(replacement.sender.setParameters).not.toHaveBeenCalled()
  expect(guard.snapshot).toMatchObject({ status: 'checking', attempts: 0 })
  guard.stop(); screenSenderStatsSampler.clear(old.sender); screenSenderStatsSampler.clear(replacement.sender)
})
