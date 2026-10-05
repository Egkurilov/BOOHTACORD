import { describe, expect, it } from 'vitest'
import { parseRealtimeEvent } from '../../realtime/realtime_client'
import { createOwnSessionsState, notifyOwnSessionsChanged } from './state'
describe('private session hints', () => {
  it('accepts empty hints and rejects embedded private metadata', () => {
    const event = { event_id: 'hint', occurred_at: '2026-10-05T00:00:00Z', kind: 'session.state_changed', payload: {} }
    expect(parseRealtimeEvent(event).kind).toBe('session.state_changed')
    expect(() => parseRealtimeEvent({ ...event, payload: { session_id: 'private' } })).toThrow()
  })
  it('refreshes an open panel and unsubscribes it on close', async () => {
    let calls = 0
    const state = createOwnSessionsState({ read: async () => { calls++; return { accountId: 'A', sessions: [], nextCursor: null } }, revoke: async () => {}, revokeOthers: async () => {} })
    state.setAccount('A'); notifyOwnSessionsChanged(); await Promise.resolve()
    expect(calls).toBe(1); state.close(); notifyOwnSessionsChanged(); expect(calls).toBe(1)
  })
})
