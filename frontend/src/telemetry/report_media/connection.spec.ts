import { afterEach, expect, it, vi } from 'vitest'
import { createConnectionReporter } from './connection'

afterEach(() => { vi.unstubAllGlobals(); vi.useRealTimers() })

it('sends fresh RTT at most every five seconds and tolerates failed delivery', async () => {
  vi.useFakeTimers()
  vi.stubGlobal('navigator', { userAgent: 'test desktop' })
  const fetch = vi.fn().mockRejectedValue(new Error('offline'))
  vi.stubGlobal('fetch', fetch)
  const report = createConnectionReporter()
  report({ quality: 'GOOD', pingMs: null })
  await vi.advanceTimersByTimeAsync(0)
  report({ quality: 'POOR', pingMs: 99 })
  expect(fetch).toHaveBeenCalledOnce()
  expect(JSON.parse(fetch.mock.calls[0]![1].body)).not.toHaveProperty('rtt_ms')
  await vi.advanceTimersByTimeAsync(5000)
  report({ quality: 'GOOD', pingMs: 12 })
  await vi.advanceTimersByTimeAsync(0)
  expect(JSON.parse(fetch.mock.calls[1]![1].body)).toMatchObject({ direction: 'connection', rtt_ms: 12, sample_age_ms: 0 })
})
