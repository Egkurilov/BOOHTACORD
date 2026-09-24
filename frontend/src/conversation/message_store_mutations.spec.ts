import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageStore } from './message_store'

const message = { id: 'message-1', channel_id: 'text-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-17T12:00:00Z', attachments: [], mention_user_ids: [] }

describe('TEXT message mutations', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('replaces an edit and immediately masks a deleted message', async () => {
    const store = useMessageStore()
    const attached = { ...message, attachments: [{ id: 'file-a', original_name: 'safe.txt', byte_size: 4 }] }
    const request = async (_input: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [attached] }))
      if (init.method === 'PATCH') return new Response(JSON.stringify({ ...message, body: 'Исправлено', revision: 2, edited_at: '2026-09-17T12:02:00Z' }))
      return new Response(null, { status: 204 })
    }

    await store.open('text-1', request)
    await expect(store.edit('message-1', 'Исправлено', 1, request)).resolves.toBe(true)
    expect(store.messages[0]?.attachments).toMatchObject([{ id: 'file-a' }])
    await expect(store.remove('message-1', request)).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ body: '', deleted: true, attachments: [], revision: 3 }])
  })

  it('preserves stable mention IDs when editing message text after a display-name change', async () => {
    const store = useMessageStore()
    let editBody: unknown
    const mentioned = { ...message, mention_user_ids: ['user-2'] }
    const request = async (_input: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [mentioned] }))
      editBody = JSON.parse(String(init.body))
      return new Response(JSON.stringify({ ...mentioned, body: 'Новое имя', revision: 2, edited_at: '2026-09-17T12:02:00Z' }))
    }
    await store.open('text-1', request)
    await expect(store.edit('message-1', 'Новое имя', 1, request)).resolves.toBe(true)
    expect(editBody).toMatchObject({ mention_user_ids: ['user-2'] })
    expect(store.messages[0]?.mentionUserIds).toEqual(['user-2'])
  })

  it('allows the editor to replace the mention list explicitly', async () => {
    const store = useMessageStore()
    let editPayload: Record<string, unknown> | undefined
    const mentioned = { ...message, mention_user_ids: ['user-2'] }
    const request = async (_input: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [mentioned] }))
      editPayload = JSON.parse(String(init.body)) as Record<string, unknown>
      return new Response(JSON.stringify({ ...mentioned, mention_user_ids: [], revision: 2, edited_at: '2026-09-17T12:02:00Z' }))
    }
    await store.open('text-1', request)
    await expect(store.edit('message-1', 'Без упоминания', 1, request, [])).resolves.toBe(true)
    expect(editPayload).not.toHaveProperty('mention_user_ids')
    expect(store.messages[0]?.mentionUserIds).toEqual([])
  })

  it('does not increment a message twice when realtime history wins a delete race', async () => {
    const store = useMessageStore()
    const deleted = { ...message, body: '', deleted: true, revision: 2 }
    const request = async (_input: string, init: RequestInit) => init.method === 'GET'
      ? new Response(JSON.stringify({ messages: [deleted] }))
      : new Response(null, { status: 204 })

    await store.open('text-1', request)
    await expect(store.remove('message-1', request)).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ body: '', deleted: true, revision: 2 }])
  })
})
