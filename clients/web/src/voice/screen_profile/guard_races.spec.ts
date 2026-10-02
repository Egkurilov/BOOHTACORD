import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { ScreenProfileGuard } from './guard'
import { profileTrack } from './fixture'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())
function deferred() { let resolve!: () => void; const promise = new Promise<void>(done => { resolve = done }); return { promise, resolve } }

it('discards pending stats after profile change and stops after disconnect', async () => {
  const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track), pending = deferred()
  await guard.apply('P1080_60')
  f.sender.getStats.mockImplementationOnce(async () => { await pending.promise; return new Map() as unknown as RTCStatsReport })
  await vi.advanceTimersByTimeAsync(5000)
  const check = guard.check()
  await guard.apply('P720_30')
  pending.resolve(); await check
  expect(guard.snapshot).toMatchObject({ status: 'checking', attempts: 0 })
  guard.stop(); await vi.advanceTimersByTimeAsync(10000); await guard.check()
  expect(guard.snapshot).toBeUndefined()
})

it('does not apply stale parameters when stopped during constraints', async () => {
  const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track), pending = deferred()
  f.mediaStreamTrack.applyConstraints.mockImplementationOnce(() => pending.promise)
  const apply = guard.apply('P1080_60')
  const rejected = expect(apply).rejects.toMatchObject({ name: 'AbortError' })
  await Promise.resolve(); guard.stop(); pending.resolve(); await rejected
  expect(f.sender.setParameters).not.toHaveBeenCalled()
})

it('serializes profile updates so the latest selection wins', async () => {
  const f = profileTrack(), guard = new ScreenProfileGuard(() => f.track), pending = deferred()
  f.mediaStreamTrack.applyConstraints.mockImplementationOnce(() => pending.promise)
  const first = guard.apply('P1080_60')
  const rejected = expect(first).rejects.toMatchObject({ name: 'AbortError' })
  await Promise.resolve()
  const second = guard.apply('P720_30')
  pending.resolve(); await rejected; await second
  expect(f.sender.setParameters).toHaveBeenCalledTimes(1)
  expect(f.sender.getParameters().encodings[0]!.maxFramerate).toBe(30)
})

it('does not repair a replacement using observations of the old track', async () => {
  const old = profileTrack(), replacement = profileTrack(), pending = deferred()
  let current = old.track
  const guard = new ScreenProfileGuard(() => current)
  await guard.apply('P1080_60')
  old.sender.getStats.mockImplementationOnce(async () => { await pending.promise; return new Map() as unknown as RTCStatsReport })
  await vi.advanceTimersByTimeAsync(5000)
  const check = guard.check()
  current = replacement.track
  pending.resolve(); await check
  await vi.advanceTimersByTimeAsync(5000); await guard.check()
  expect(replacement.sender.setParameters).not.toHaveBeenCalled()
  expect(guard.snapshot).toMatchObject({ status: 'checking', attempts: 0 })
})

it('orders a user change after an in-flight parameter write', async () => {
  const f = profileTrack(), pending = deferred(), guard = new ScreenProfileGuard(() => f.track)
  f.sender.setParameters.mockImplementationOnce(async () => pending.promise)
  const first = guard.apply('P1080_60')
  const rejected = expect(first).rejects.toMatchObject({ name: 'AbortError' })
  await vi.advanceTimersByTimeAsync(0)
  expect(f.sender.setParameters).toHaveBeenCalledTimes(1)
  const second = guard.apply('P720_30')
  pending.resolve(); await rejected; await second
  expect(f.sender.getParameters().encodings[0]!.maxFramerate).toBe(30)
  expect(guard.snapshot).toMatchObject({ status: 'checking', attempts: 0 })
})
