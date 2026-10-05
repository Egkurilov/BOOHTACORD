import { afterEach, expect, it, vi } from 'vitest'
import { createProtectedRefreshGate } from './gate'
afterEach(() => vi.useRealTimers())
it('coalesces 1, 20 and 50 hints and never overlaps a resource fetch', async () => {
  vi.useFakeTimers()
  for (const count of [1, 20, 50]) {
    const gate = createProtectedRefreshGate()
    const fetch = vi.fn(async () => {})
    const hints = Array.from({ length: count }, () => gate.run('text', fetch))
    await vi.runAllTimersAsync()
    await Promise.all(hints)
    expect(fetch).toHaveBeenCalledOnce()
    gate.close()
  }
})
it('fetches once more when dirtied during an in-flight request', async () => {
  vi.useFakeTimers()
  const gate = createProtectedRefreshGate()
  let finish!: () => void
  let revision = 1, applied = 0, concurrent = 0, maximum = 0
  const fetch = vi.fn(async () => {
    concurrent++; maximum = Math.max(maximum, concurrent)
    const current = revision
    if (fetch.mock.calls.length === 1) await new Promise<void>(resolve => { finish = resolve })
    applied = current; concurrent--
  })
  const first = gate.run('text', fetch)
  await vi.advanceTimersByTimeAsync(30)
  revision = 50
  const second = gate.run('text', fetch)
  finish()
  await Promise.all([first, second])
  expect(fetch).toHaveBeenCalledTimes(2)
  expect(maximum).toBe(1)
  expect(applied).toBe(50)
})
it('closing cancels pending work without invoking its transport', async () => {
  vi.useFakeTimers()
  const gate = createProtectedRefreshGate()
  const fetch = vi.fn(async () => {})
  const work = gate.run('dm', fetch)
  gate.close()
  await work
  await vi.runAllTimersAsync()
  expect(fetch).not.toHaveBeenCalled()
})
