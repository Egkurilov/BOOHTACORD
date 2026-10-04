import { describe, expect, it } from 'vitest'
import type { AuditEvent } from '../../identity/admin_directory_client'
import { appendAuditPage, filterAuditEvents, groupAuditDays } from './audit_filter'

const events: AuditEvent[] = [
  { id: 'a', event_type: 'VOICE_LEASE_KICKED', actor_user_id: 'owner', actor_display_name: 'Егор', target_user_id: 'member', created_at: '2026-10-04T12:30:00Z' },
  { id: 'b', event_type: 'ACCOUNT_ADMIN_STATE_UPDATED', actor_user_id: 'owner', actor_display_name: 'Егор', target_user_id: 'member', created_at: '2026-10-04T11:00:00Z' },
  { id: 'c', event_type: 'CHANNEL_RENAMED', actor_user_id: 'other', created_at: '2026-10-03T14:00:00Z' },
]

describe('administrator audit filtering', () => {
  it('separates voice and administration by event metadata', () => {
    expect(filterAuditEvents(events, { scope: 'voice' }).map(({ id }) => id)).toEqual(['a'])
    expect(filterAuditEvents(events, { scope: 'admin' }).map(({ id }) => id)).toEqual(['b', 'c'])
  })

  it('combines inclusive dates, action type, and exact actor', () => {
    const filtered = filterAuditEvents(events, { scope: 'all', from: '2026-10-04', to: '2026-10-04', type: 'ACCOUNT_ADMIN_STATE_UPDATED', actor: 'owner' })
    expect(filtered.map(({ id }) => id)).toEqual(['b'])
    expect(filterAuditEvents(events, { scope: 'all', to: '2026-10-03' }).map(({ id }) => id)).toEqual(['c'])
  })

  it('groups without losing order and avoids duplicates when a cursor page overlaps', () => {
    expect(groupAuditDays(events).map(({ events }) => events.map(({ id }) => id))).toEqual([['a', 'b'], ['c']])
    expect(appendAuditPage(events, [events[2], { ...events[2], id: 'd' }]).map(({ id }) => id)).toEqual(['a', 'b', 'c', 'd'])
  })
})
