import { describe, expect, it } from 'vitest'

import type { RealtimeEvent } from '../realtime/realtime_client'
import { shouldRefreshTextHistory } from './active_message_resync'

const channelId = '11111111-1111-4111-8111-111111111111'
const event = (kind: RealtimeEvent['kind'], channel = channelId): RealtimeEvent => ({ eventId: '33333333-3333-4333-8333-333333333333', kind, occurredAt: '2026-09-24T10:00:00Z', payload: { channel_id: channel } })

describe('active text history realtime routing', () => {
  it.each(['message.created', 'message.updated', 'message.deleted'] as const)('refreshes the active text channel for %s', (kind) => {
    expect(shouldRefreshTextHistory(event(kind), channelId, false)).toBe(true)
  })

  it('ignores hints for another channel and all hints while a DM is selected', () => {
    expect(shouldRefreshTextHistory(event('message.deleted', '22222222-2222-4222-8222-222222222222'), channelId, false)).toBe(false)
    expect(shouldRefreshTextHistory(event('message.created'), channelId, true)).toBe(false)
  })

  it('does not route other event kinds into text history', () => {
    expect(shouldRefreshTextHistory(event('connection.resync_required'), channelId, false)).toBe(false)
  })
})
