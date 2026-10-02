import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { loadDirectMessageHistory } from './direct_message_client'
import { createDirectMessage } from './direct_message_mutation_client'
import { uploadDirectMessageAttachment } from './direct_message_attachment_upload_client'
import { useDirectMessageStore } from './direct_message_store'

const metadata = { id: 'attachment-a', original_name: 'safe.png', byte_size: 4 }
const message = { id: 'message-a', direct_message_id: 'dm-a', author_id: 'me', client_message_id: 'client-a', body: 'Файл',
  created_at: '2026-09-25T10:00:00Z', revision: 1, deleted: false, mention_user_ids: [], attachments: [metadata] }

describe('direct-message attachment model and API', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('uploads only to the addressed DM with same-origin credentials and validates metadata', async () => {
    const file = new File(['file'], 'safe.png', { type: 'image/png' })
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify(metadata), { status: 201 }))
    await expect(uploadDirectMessageAttachment('dm/a', file, request)).resolves.toEqual({ id: 'attachment-a', originalName: 'safe.png', sizeBytes: 4 })
    expect(request).toHaveBeenCalledWith('/api/v1/direct-messages/dm%2Fa/attachments', expect.objectContaining({ method: 'POST', credentials: 'same-origin' }))
    expect((request.mock.calls[0]?.[1].body as FormData).get('file')).toMatchObject({ name: 'safe.png', size: 4 })
    await expect(uploadDirectMessageAttachment('dm-a', new File(['x'], 'large', { type: 'text/plain' }), vi.fn().mockResolvedValue(new Response(JSON.stringify({ ...metadata, byte_size: -1 }))))).rejects.toThrow('некорректные')
  })

  it('parses private history metadata and hides deleted attachments', async () => {
    const request = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ messages: [message] })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ messages: [{ ...message, deleted: true, body: '', revision: 2, attachments: [] }] })))
    await expect(loadDirectMessageHistory('dm-a', undefined, request)).resolves.toMatchObject({ messages: [{ attachments: [{ id: 'attachment-a', originalName: 'safe.png', sizeBytes: 4 }] }] })
    await expect(loadDirectMessageHistory('dm-a', undefined, request)).resolves.toMatchObject({ messages: [{ deleted: true, attachments: [] }] })
  })

  it('drops revoked metadata on refresh and refuses deleted rows that still expose a file', async () => {
    const store = useDirectMessageStore()
    let visible = message
    const request = async () => new Response(JSON.stringify({ messages: [visible] }))
    await store.open('dm-a', request)
    expect(store.messages[0]?.attachments).toHaveLength(1)
    visible = { ...message, attachments: [] }
    await store.refreshHistory(request)
    expect(store.messages[0]?.attachments).toEqual([])
    const invalid = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [{ ...message, deleted: true, body: '' }] })))
    await expect(loadDirectMessageHistory('dm-a', undefined, invalid)).rejects.toThrow('некорректные данные вложения')
  })

  it('sends attachment IDs and retains the exact IDs for retry and optimistic history', async () => {
    const store = useDirectMessageStore()
    const payloads: Record<string, unknown>[] = []
    const request = async (_path: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [] }))
      payloads.push(JSON.parse(String(init.body)))
      if (payloads.length === 1) throw new Error('network')
      return new Response(JSON.stringify({ ...message, attachments: undefined }))
    }
    await store.open('dm-a', request)
    await expect(store.send('Файл', request, () => 'client-a', undefined, 'me', [], [{ id: 'attachment-a', originalName: 'safe.png', sizeBytes: 4 }])).resolves.toBe(false)
    expect(store.messages).toMatchObject([{ sendStatus: 'failed', attachments: [{ id: 'attachment-a' }] }])
    await expect(store.retry('client-a', request)).resolves.toBe(true)
    expect(payloads).toMatchObject([{ attachment_ids: ['attachment-a'] }, { attachment_ids: ['attachment-a'] }])
    expect(store.messages).toMatchObject([{ id: 'message-a', attachments: [{ id: 'attachment-a' }] }])
  })

  it('includes attachment_ids in direct send contract', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ ...message, attachments: undefined })))
    await createDirectMessage('dm-a', 'client-a', 'Файл', request, undefined, [], ['attachment-a'])
    expect(JSON.parse(String(request.mock.calls[0]?.[1].body))).toMatchObject({ attachment_ids: ['attachment-a'] })
  })

  it('keeps upload failures bounded and does not send oversized files', async () => {
    const file = new File(['x'], 'x.txt')
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { code: 'INSUFFICIENT_STORAGE' } }), { status: 507 }))
    await expect(uploadDirectMessageAttachment('dm-a', file, request)).rejects.toThrow('507: INSUFFICIENT_STORAGE')
    await expect(uploadDirectMessageAttachment('dm-a', { name: 'large', size: 25_000_001 } as File, request)).rejects.toThrow('ограничению')
    expect(request).toHaveBeenCalledOnce()
  })
})
