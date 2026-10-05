import { afterEach, expect, it, vi } from 'vitest'
import { createReconnectSchedule } from './controller'
afterEach(() => vi.useRealTimers())
it('keeps one timer, resets attempts on ready and cancels pending reconnect', async () => {
  vi.useFakeTimers()
  const open = vi.fn()
  const retry = createReconnectSchedule(open, () => 0)
  retry.schedule(); retry.schedule()
  expect(retry.attempt()).toBe(1)
  await vi.runAllTimersAsync()
  expect(open).toHaveBeenCalledOnce()
  retry.schedule(); retry.stop()
  await vi.runAllTimersAsync()
  expect(open).toHaveBeenCalledOnce()
  retry.ready()
  expect(retry.attempt()).toBe(0)
})
