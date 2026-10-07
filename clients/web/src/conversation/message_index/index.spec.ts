import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'
import { useMessageStore } from '../message_store'

const first = { id: 'message-1', channel_id: 'text-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Target', revision: 1, created_at: '2026-09-17T12:00:00Z', attachments: [], mention_user_ids: [] }
const reply = { ...first, id: 'message-2', client_message_id: 'client-2', reply_to_id: 'message-1', body: 'Reply', created_at: '2026-09-17T12:01:00Z' }

describe('message lookup index', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('indexes loaded replies and follows edit, tombstone and channel reset mutations', async () => {
    const store = useMessageStore()
    const request = async (url: string, init: RequestInit) => {
      if (init.method === 'PATCH') return new Response(JSON.stringify({ ...first, body: 'Edited', revision: 2, edited_at: '2026-09-17T12:02:00Z' }))
      if (init.method === 'DELETE') return new Response(null, { status: 204 })
      return new Response(JSON.stringify({ messages: url.includes('text-2') ? [] : [reply, first] }))
    }

    await store.open('text-1', request)
    expect(store.messageById.get(store.messages.find((message) => message.id === 'message-2')!.replyToId!)).toMatchObject({ id: 'message-1', body: 'Target' })
    await store.edit('message-1', 'Edited', 1, request)
    expect(store.messageById.get('message-1')?.body).toBe('Edited')
    await store.remove('message-1', request)
    expect(store.messageById.get('message-1')).toMatchObject({ deleted: true, body: '', attachments: [] })
    await store.open('text-2', request)
    expect(store.messageById.has('message-1')).toBe(false)
  })
})
