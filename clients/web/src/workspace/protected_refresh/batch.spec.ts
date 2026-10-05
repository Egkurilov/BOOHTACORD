import { expect, it, vi } from 'vitest'
import type { RealtimeEvent } from '../../realtime/realtime_client'
import { deliverProtectedHintBatch } from './batch'

const hint = (kind: RealtimeEvent['kind'], payload: Record<string, unknown>): RealtimeEvent =>
  ({ kind, payload, eventId: 'hint', occurredAt: '2026-10-05T00:00:00Z' })

it('keeps text and DM notification scopes independent while every hint refreshes', async () => {
  const handler = vi.fn(async (_event: RealtimeEvent, _notify?: boolean) => {})
  const events = [hint('message.created', { channel_id: 'a' }), hint('message.created', { channel_id: 'a' }),
    hint('direct_message.message_created', { direct_message_id: 'a' }), hint('message.created', { channel_id: 'b' })]
  await deliverProtectedHintBatch(events, handler)
  expect(handler.mock.calls.map(call => call[1])).toEqual([true, false, true, true])
  expect(handler.mock.calls.map(call => call[0])).toEqual(events)
})

it('retains protected refresh failure for durable replay', async () => {
  const failure = new Error('protected refresh failed')
  await expect(deliverProtectedHintBatch([hint('message.created', { channel_id: 'a' })],
    async () => { throw failure })).rejects.toBe(failure)
})
