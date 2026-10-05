import { expect, it, vi } from 'vitest'
import { refreshEditedHints } from './revisions'
import type { RealtimeEvent } from '../../realtime/realtime_client'

it.each(['message.updated', 'message.deleted'] as const)('does not fetch retained TEXT history behind an active DM on %s', async kind => {
  const refreshMessages = vi.fn(async () => {})
  const stores = {
    topology: { error: null, refresh: vi.fn(async () => {}) },
    messages: { channelId: 'retained-text', error: null, refresh: vi.fn(async () => {}), refreshMessages },
    directMessages: { directMessageId: 'active-dm' as string | null, error: null,
      refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}) },
  }
  const event: RealtimeEvent = { eventId: 'hint', occurredAt: '2026-10-05T00:00:00Z', kind,
    payload: { channel_id: 'retained-text', message_id: 'old-message', revision: 2 } }
  await refreshEditedHints(stores, [event])
  expect(refreshMessages).not.toHaveBeenCalled()
  stores.directMessages.directMessageId = null
  await refreshEditedHints(stores, [event])
  expect(refreshMessages).toHaveBeenCalledWith(['old-message'])
})
