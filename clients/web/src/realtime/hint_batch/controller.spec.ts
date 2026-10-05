import { afterEach, expect, it, vi } from 'vitest'
import { createCoalescedDelivery } from './controller'
import type { RealtimeEvent } from '../realtime_client'
afterEach(() => vi.useRealTimers())
function hint(id: string): RealtimeEvent {
  return { eventId: id, kind: 'message.created', occurredAt: '2026-10-05T00:00:00Z', payload: { channel_id: 'room', message_id: id } }
}
it('batches durable hints and acknowledges only after protected work succeeds', async () => {
  vi.useFakeTimers()
  let finish!: () => void
  const batch = vi.fn((_events: RealtimeEvent[]) => new Promise<void>(resolve => { finish = resolve }))
  const delivery = createCoalescedDelivery(vi.fn(), undefined, vi.fn(), batch)
  for (let index = 0; index < 50; index++) delivery.accept(hint(String(index)))
  await vi.advanceTimersByTimeAsync(30)
  expect(batch).toHaveBeenCalledOnce()
  expect(batch.mock.calls[0][0]).toHaveLength(50)
  expect(delivery.cursor()).toBeNull()
  finish(); await Promise.resolve(); await Promise.resolve()
  expect(delivery.cursor()).toBe('49')
  delivery.accept(hint('0'))
  await vi.runAllTimersAsync()
  expect(batch).toHaveBeenCalledOnce()
})
it('revokes immediately while a REST batch is blocked, without advancing its cursor', async () => {
  vi.useFakeTimers()
  let finish!: () => void
  const onEvent = vi.fn()
  const delivery = createCoalescedDelivery(onEvent, undefined, vi.fn(), () => new Promise<void>(resolve => { finish = resolve }))
  delivery.accept(hint('first')); await vi.advanceTimersByTimeAsync(30)
  const revoke = { ...hint('revoke'), kind: 'voice.lease_revoked' as const, payload: { lease_id: 'lease', reason: 'session_revoked' } }
  delivery.accept(revoke)
  expect(onEvent).toHaveBeenCalledWith(revoke)
  expect(delivery.cursor()).toBeNull()
  finish(); await Promise.resolve(); await Promise.resolve(); await Promise.resolve()
  expect(onEvent).toHaveBeenCalledOnce()
})
