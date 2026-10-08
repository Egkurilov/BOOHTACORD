import { describe, expect, it, vi } from 'vitest'

import { createTextMessage, deleteTextMessage, editTextMessage, loadMessagePage } from './message_client'

const body = {
  id: 'message-1', channel_id: 'text-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-17T12:00:00Z', deleted: false,
  attachments: [{ id: 'attachment-1', original_name: 'notes.svg', byte_size: 10 }], mention_user_ids: [],
}

describe('message client', () => {
  it('reads a same-origin page without interpreting message text as HTML', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [body], next_cursor: 'message-1' })))

    await expect(loadMessagePage('text-1', undefined, request)).resolves.toMatchObject({ nextCursor: 'message-1', messages: [{ body: 'Привет', attachments: [{ id: 'attachment-1', originalName: 'notes.svg', sizeBytes: 10 }] }] })
    expect(request).toHaveBeenCalledWith('/api/v1/channels/text-1/messages', expect.objectContaining({ method: 'GET', credentials: 'same-origin' }))
  })

  it('requests the protected message anchor and a bounded context page', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [body] })))
    await expect(loadMessagePage('text-1', undefined, request, 'message-1')).resolves.toMatchObject({ messages: [{ id: 'message-1' }] })
    expect(request).toHaveBeenCalledWith('/api/v1/channels/text-1/messages?at=message-1&limit=20', expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('requests the next newer page from its protected cursor', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [body], next_cursor: 'message-2' })))
    await expect(loadMessagePage('text-1', undefined, request, undefined, 'message-1')).resolves.toMatchObject({ nextCursor: 'message-2' })
    expect(request).toHaveBeenCalledWith('/api/v1/channels/text-1/messages?after=message-1&limit=20', expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('rejects history that omits the required safe attachment array', async () => {
    const { attachments: _attachments, ...withoutAttachments } = body
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [withoutAttachments] })))

    await expect(loadMessagePage('text-1', undefined, request)).rejects.toThrow('некорректное сообщение')
  })

  it('uses guarded mutation endpoints and exposes a conflict response', async () => {
    const request = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify(body)))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ...body, body: 'Исправлено', revision: 2 })))
      .mockResolvedValueOnce(new Response(null, { status: 204 }))

    await expect(createTextMessage('text-1', 'client-1', 'Привет', request, 'message-0', ['attachment-1'])).resolves.toMatchObject({ id: 'message-1' })
    await expect(editTextMessage('text-1', 'message-1', 'Исправлено', 1, request)).resolves.toMatchObject({ revision: 2 })
    await expect(deleteTextMessage('text-1', 'message-1', request)).resolves.toBeUndefined()
    expect(request).toHaveBeenNthCalledWith(1, '/api/v1/channels/text-1/messages', expect.objectContaining({ body: '{"client_message_id":"client-1","body":"Привет","reply_to_id":"message-0","attachment_ids":["attachment-1"]}' }))
    expect(request).toHaveBeenNthCalledWith(2, '/api/v1/channels/text-1/messages/message-1', expect.objectContaining({ method: 'PATCH', body: '{"body":"Исправлено","expected_revision":1}' }))
    expect(request).toHaveBeenNthCalledWith(3, '/api/v1/channels/text-1/messages/message-1', expect.objectContaining({ method: 'DELETE' }))
  })

  it('sends stable mention user IDs independent of the display name and preserves them on edit', async () => {
    const mentioned = { ...body, mention_user_ids: ['user-2'] }
    const request = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify(mentioned)))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ...mentioned, revision: 2, edited_at: '2026-09-17T12:01:00Z' })))
    await expect(createTextMessage('text-1', 'client-1', 'Привет', request, undefined, [], ['user-2'])).resolves.toMatchObject({ mentionUserIds: ['user-2'] })
    await expect(editTextMessage('text-1', 'message-1', 'Новое имя в тексте', 1, request, ['user-2'])).resolves.toMatchObject({ mentionUserIds: ['user-2'] })
    expect(JSON.parse(String(request.mock.calls[0][1].body)).mention_user_ids).toEqual(['user-2'])
    expect(JSON.parse(String(request.mock.calls[1][1].body)).mention_user_ids).toEqual(['user-2'])
  })
})
