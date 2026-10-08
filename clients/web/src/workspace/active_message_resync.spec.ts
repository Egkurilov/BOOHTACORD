import { describe, expect, it, vi } from 'vitest'

import type { RealtimeEvent } from '../realtime/realtime_client'
import { applyDeletedMessageHint, shouldRefreshTextHistory } from './active_message_resync'

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

  it('forwards deletion hints only to the matching active conversation', () => {
    const textDelete = vi.fn(), dmDelete = vi.fn()
    const histories = { messages: { channelId, applyDeletedHint: textDelete }, directMessages: { directMessageId: 'dm-a' as string | null, applyDeletedHint: dmDelete } }
    applyDeletedMessageHint({ kind: 'direct_message.message_deleted', payload: { direct_message_id: 'dm-a', message_id: 'dm-message' } }, histories)
    histories.directMessages.directMessageId = null
    applyDeletedMessageHint({ kind: 'message.deleted', payload: { channel_id: channelId, message_id: 'text-message' } }, histories)
    applyDeletedMessageHint({ kind: 'message.deleted', payload: { channel_id: 'other', message_id: 'foreign' } }, histories)
    expect(dmDelete).toHaveBeenCalledOnce()
    expect(dmDelete).toHaveBeenCalledWith('dm-a', 'dm-message')
    expect(textDelete).toHaveBeenCalledOnce()
    expect(textDelete).toHaveBeenCalledWith(channelId, 'text-message')
  })
})
