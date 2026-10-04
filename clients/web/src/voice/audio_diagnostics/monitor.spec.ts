import { afterEach, expect, it, vi } from 'vitest'
import { monitorAudioSamples } from './monitor'
afterEach(() => vi.useRealTimers())
it('serializes samples and drops completions after disposal', async () => {
  vi.useFakeTimers()
  let resolve!: (value: number) => void
  const read = vi.fn(() => new Promise<number>((done) => { resolve = done }))
  const publish = vi.fn()
  const stop = monitorAudioSamples(read, publish)
  await vi.advanceTimersByTimeAsync(6000)
  expect(read).toHaveBeenCalledTimes(1)
  stop(); resolve(64)
  await vi.advanceTimersByTimeAsync(0)
  expect(publish).not.toHaveBeenCalled()
})
it('keeps unavailable stats unknown and recovers on the next sample', async () => {
  vi.useFakeTimers()
  const read = vi.fn().mockRejectedValueOnce(new Error('unsupported')).mockResolvedValue(96)
  const publish = vi.fn()
  const stop = monitorAudioSamples(read, publish)
  await vi.advanceTimersByTimeAsync(2000)
  expect(publish.mock.calls).toEqual([[null], [96]])
  stop()
})
