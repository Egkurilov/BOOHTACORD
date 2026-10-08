import { describe, expect, it, vi } from 'vitest'

import { createMemberProfileRefresh } from './member_profile_realtime'
import type { RealtimeEvent } from '../realtime/realtime_client'

describe('member profile realtime invalidation', () => {
  it('invalidates member metadata and refreshes protected roster and direct navigation', async () => {
    const authors = { invalidate: vi.fn(async () => {}) }
    const members = { invalidate: vi.fn(async () => {}), error: null as string | null }
    const direct = { refreshNavigation: vi.fn(async () => {}), error: null as string | null }
    const event: RealtimeEvent = {
      eventId: 'evt', kind: 'member.profile.updated', occurredAt: '2026-10-08T10:00:00Z',
      payload: { user_id: 'member-1', revision: 4 },
    }
    expect(await createMemberProfileRefresh(authors, members)(event, direct)).toBe(true)
    expect(authors.invalidate).toHaveBeenCalledWith('member-1', 4)
    expect(members.invalidate).toHaveBeenCalledOnce()
    expect(direct.refreshNavigation).toHaveBeenCalledOnce()
  })

  it('ignores unrelated events and malformed revisions', async () => {
    const authors = { invalidate: vi.fn(async () => {}) }
    const members = { invalidate: vi.fn(async () => {}), error: null as string | null }
    const direct = { refreshNavigation: vi.fn(async () => {}), error: null as string | null }
    const refresh = createMemberProfileRefresh(authors, members)
    const event: RealtimeEvent = {
      eventId: 'evt', kind: 'message.deleted', occurredAt: '2026-10-08T10:00:00Z',
      payload: { user_id: 'member-1', revision: 4 },
    }
    expect(await refresh(event, direct)).toBe(false)
    expect(authors.invalidate).not.toHaveBeenCalled()
    expect(direct.refreshNavigation).not.toHaveBeenCalled()
  })
})
