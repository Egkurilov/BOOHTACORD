import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageStore } from './message_store'

const message = { id: 'message-1', channel_id: 'text-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-17T12:00:00Z', attachments: [] }

describe('message store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('loads a channel then prepends a server-created message', async () => {
    const store = useMessageStore()
    const request = async (_input: string, init: RequestInit) => init.method === 'GET'
      ? new Response(JSON.stringify({ messages: [] }))
      : new Response(JSON.stringify(message))

    await store.open('text-1', request)
    const attachments = [{ id: 'attachment-1', originalName: 'notes.txt', sizeBytes: 4 }]
    await expect(store.send('Привет', request, () => 'client-1', undefined, attachments)).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ id: 'message-1', createdAt: '2026-09-17T12:00:00Z', attachments }])
  })

  it('replaces an edit and immediately masks a deleted message', async () => {
    const store = useMessageStore()
    const request = async (_input: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [message] }))
      if (init.method === 'PATCH') return new Response(JSON.stringify({ ...message, body: 'Исправлено', revision: 2, edited_at: '2026-09-17T12:02:00Z' }))
      return new Response(null, { status: 204 })
    }

    await store.open('text-1', request)
    await expect(store.edit('message-1', 'Исправлено', 1, request)).resolves.toBe(true)
    await expect(store.remove('message-1', request)).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ body: '', deleted: true, revision: 3 }])
  })
})
