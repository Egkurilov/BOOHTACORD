import { afterEach, expect, it, vi } from 'vitest'
import { createRealtimeDelivery } from '../../realtime/realtime_event_delivery'
import { createCoalescedDelivery } from '../../realtime/hint_batch/controller'
import { coalesceStores } from './stores'
import { createProtectedRefreshGate } from './gate'
import type { RealtimeEvent } from '../../realtime/realtime_client'
afterEach(() => vi.useRealTimers())
it('measures native REST invocations for 1/20/50 active and hidden hints before/after', async () => {
  vi.useFakeTimers()
  for (const active of [true, false]) for (const count of [1, 20, 50]) {
    const source = () => ({
      topology: { error: null, refresh: vi.fn(async () => {}) },
      messages: { error: null, channelId: active ? 'room' : null, refresh: vi.fn(async () => {}) },
      directMessages: { error: null, directMessageId: null, refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}) },
    })
    const before = source(), after = source(), gate = createProtectedRefreshGate()
    const coalesced = coalesceStores(after, gate)
    const callback = (stores: typeof before) => async () => {
      await Promise.all([stores.topology.refresh(), active ? stores.messages.refresh() : Promise.resolve()])
    }
    const baseline = createRealtimeDelivery(callback(before), undefined, cause => { throw cause })
    const handler = callback(coalesced as typeof before)
    const changed = createCoalescedDelivery(handler, undefined, cause => { throw cause }, events => Promise.all(events.map(handler)).then(() => {}))
    for (let index = 0; index < count; index++) {
      const event: RealtimeEvent = { eventId: String(index), kind: 'message.created', occurredAt: '2026-10-05T00:00:00Z', payload: { channel_id: 'room', message_id: String(index) } }
      baseline.accept(event); changed.accept(event)
    }
    await vi.runAllTimersAsync()
    expect(before.topology.refresh).toHaveBeenCalledTimes(count)
    expect(after.topology.refresh).toHaveBeenCalledOnce()
    expect(before.messages.refresh).toHaveBeenCalledTimes(active ? count : 0)
    expect(after.messages.refresh).toHaveBeenCalledTimes(active ? 1 : 0)
    gate.close(); baseline.reset(); changed.reset()
  }
})
