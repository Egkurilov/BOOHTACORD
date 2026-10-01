import { describe, expect, it, vi } from 'vitest'

import { advanceDirectMessageReadCursor, loadDirectMessageHistory, loadDirectMessages } from './direct_message_client'

const directMessage = {
  id: 'dm-1', other_participant_id: 'user-2', other_participant_display_name: 'Лера',
  created_at: '2026-09-18T10:00:00Z', unread_count: 3, mention_count: 2, first_unread_message_id: 'message-1',
}

const deletedHistoryItem = {
  id: 'message-2', direct_message_id: 'dm-1', author_id: 'user-2', client_message_id: 'client-2',
  body: '', created_at: '2026-09-18T10:02:00Z', revision: 2, deleted: true, mention_user_ids: [],
  reply_to_id: 'message-1', reply_preview: { id: 'message-1', author_id: 'user-1', body: '', deleted: true },
}

describe('direct-message client', () => {
  it('reads the caller-local navigation count through a same-origin GET', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ direct_messages: [directMessage] })))

    await expect(loadDirectMessages(request)).resolves.toMatchObject([{ id: 'dm-1', unreadCount: 3, mentionCount: 2, firstUnreadMessageId: 'message-1' }])
    expect(request).toHaveBeenCalledWith('/api/v1/direct-messages', expect.objectContaining({ method: 'GET', credentials: 'same-origin' }))
  })

  it('rejects a missing or negative caller-local DM mention counter', async () => {
    const missing = vi.fn().mockResolvedValue(new Response(JSON.stringify({ direct_messages: [{ ...directMessage, mention_count: undefined }] })))
    const negative = vi.fn().mockResolvedValue(new Response(JSON.stringify({ direct_messages: [{ ...directMessage, mention_count: -1 }] })))
    await expect(loadDirectMessages(missing)).rejects.toThrow('некоррект')
    await expect(loadDirectMessages(negative)).rejects.toThrow('некоррект')
  })

  it('keeps a deleted reply preview empty while loading a paginated DM history', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [deletedHistoryItem], next_cursor: 'message-1' })))

    await expect(loadDirectMessageHistory('dm-1', undefined, request)).resolves.toMatchObject({ nextCursor: 'message-1', messages: [{ deleted: true, body: '', replyPreview: { deleted: true, body: '' } }] })
    expect(request).toHaveBeenCalledWith('/api/v1/direct-messages/dm-1/messages', expect.objectContaining({ method: 'GET', credentials: 'same-origin' }))
  })

  it('requests a bounded context page through the participant-only history route', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [deletedHistoryItem] })))
    await expect(loadDirectMessageHistory('dm-1', undefined, request, 'message-2')).resolves.toMatchObject({ messages: [{ id: 'message-2', deleted: true }] })
    expect(request).toHaveBeenCalledWith('/api/v1/direct-messages/dm-1/messages?at=message-2&limit=20', expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('rejects a deleted item that carries hidden text', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [{ ...deletedHistoryItem, body: 'secret' }] })))

    await expect(loadDirectMessageHistory('dm-1', undefined, request)).rejects.toThrow('некорректную историю')
  })

  it('advances one caller cursor through the guarded same-origin endpoint', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      direct_message_id: 'dm-1', message_id: 'message-2', message_created_at: '2026-09-18T10:02:00Z',
    })))

    await expect(advanceDirectMessageReadCursor('dm-1', 'message-2', request)).resolves.toMatchObject({ directMessageId: 'dm-1', messageId: 'message-2' })
    expect(request).toHaveBeenCalledWith('/api/v1/direct-messages/dm-1/read-cursor', expect.objectContaining({ method: 'PUT', credentials: 'same-origin', body: '{"message_id":"message-2"}' }))
  })
})
