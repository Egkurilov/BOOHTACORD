import { afterEach, expect, it, vi } from 'vitest'
import { createCoalescedDelivery } from './controller'
import type { RealtimeEvent } from '../realtime_client'
afterEach(() => vi.useRealTimers())
const revoke: RealtimeEvent = { eventId: 'revoke', kind: 'voice.lease_revoked',
  occurredAt: '2026-10-05T00:00:00Z', payload: { lease_id: 'lease', reason: 'session_revoked' } }
it('retries a failed immediate revoke on durable replay', async () => {
  const onEvent = vi.fn().mockRejectedValueOnce(new Error('teardown')).mockResolvedValue(undefined)
  const failure = vi.fn()
  const delivery = createCoalescedDelivery(onEvent, undefined, failure, vi.fn())
  delivery.accept(revoke)
  await vi.waitFor(() => expect(failure).toHaveBeenCalledOnce())
  expect(delivery.cursor()).toBeNull()
  delivery.accept({ ...revoke })
  await vi.waitFor(() => expect(delivery.cursor()).toBe('revoke'))
  expect(onEvent).toHaveBeenCalledTimes(2)
})
it('acknowledges a revoke replay after an earlier blocked batch failed', async () => {
  vi.useFakeTimers()
  let reject!: (cause: Error) => void
  const onEvent = vi.fn().mockResolvedValue(undefined)
  const failure = vi.fn()
  const delivery = createCoalescedDelivery(onEvent, undefined, failure,
    () => new Promise<void>((_, fail) => { reject = fail }))
  delivery.accept({ ...revoke, eventId: 'hint', kind: 'message.created', payload: { channel_id: 'room', message_id: 'row' } })
  await vi.advanceTimersByTimeAsync(30)
  delivery.accept(revoke)
  reject(new Error('REST unavailable'))
  await vi.advanceTimersByTimeAsync(1)
  expect(delivery.cursor()).toBeNull()
  delivery.accept({ ...revoke })
  await vi.advanceTimersByTimeAsync(1)
  expect(delivery.cursor()).toBe('revoke')
})
