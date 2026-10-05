import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { loadDirectMessageHistory } from './direct_message_client'
import { createDirectMessage, editDirectMessage } from './direct_message_mutation_client'
import { useDirectMessageStore } from './direct_message_store'

const message = { id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1',
  body: 'Привет', revision: 1, created_at: '2026-09-25T00:00:00Z', deleted: false, mention_user_ids: ['user-2'] }

describe('DM mentions by stable user ID', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('parses recipient IDs from history and sends them in create/edit', async () => {
    const history = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [message] })))
    await expect(loadDirectMessageHistory('dm-1', undefined, history)).resolves.toMatchObject({ messages: [{ mentionUserIds: ['user-2'] }] })
    const request = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify(message)))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ...message, revision: 2, edited_at: '2026-09-25T00:01:00Z' })))
    await expect(createDirectMessage('dm-1', 'client-1', 'Привет', request, undefined, ['user-2'])).resolves.toMatchObject({ mentionUserIds: ['user-2'] })
    await expect(editDirectMessage('dm-1', 'message-1', 'Новое имя', 1, request, ['user-2'])).resolves.toMatchObject({ mentionUserIds: ['user-2'] })
    expect(JSON.parse(String(request.mock.calls[0][1].body)).mention_user_ids).toEqual(['user-2'])
    expect(JSON.parse(String(request.mock.calls[1][1].body)).mention_user_ids).toEqual(['user-2'])
  })

  it('retries the same mention IDs and idempotency key after a lost response', async () => {
    const store = useDirectMessageStore()
    const payloads: unknown[] = []
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'user-1', message_id: null }))
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [] }))
      payloads.push(JSON.parse(String(init.body)))
      if (payloads.length === 1) throw new Error('Сеть недоступна')
      return new Response(JSON.stringify(message))
    }
    await store.open('dm-1', request)
    await expect(store.send('Привет', request, () => 'client-1', undefined, 'user-1', ['user-2'])).resolves.toBe(false)
    await expect(store.retry('client-1', request)).resolves.toBe(true)
    expect(payloads).toMatchObject([
      { client_message_id: 'client-1', mention_user_ids: ['user-2'] },
      { client_message_id: 'client-1', mention_user_ids: ['user-2'] },
    ])
  })

  it('preserves the peer ID when the author edits text after the peer changes name', async () => {
    const store = useDirectMessageStore()
    let editPayload: unknown
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'user-1', message_id: null }))
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [message] }))
      editPayload = JSON.parse(String(init.body))
      return new Response(JSON.stringify({ ...message, body: 'Новое имя', revision: 2, edited_at: '2026-09-25T00:01:00Z' }))
    }
    await store.open('dm-1', request)
    await expect(store.edit('message-1', 'Новое имя', 1, request)).resolves.toBe(true)
    expect(editPayload).toMatchObject({ mention_user_ids: ['user-2'] })
    expect(store.messages[0]?.mentionUserIds).toEqual(['user-2'])
  })

  it('allows the editor to remove a previous DM mention', async () => {
    const store = useDirectMessageStore()
    let editPayload: Record<string, unknown> | undefined
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'user-1', message_id: null }))
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [message] }))
      editPayload = JSON.parse(String(init.body)) as Record<string, unknown>
      return new Response(JSON.stringify({ ...message, mention_user_ids: [], revision: 2, edited_at: '2026-09-25T00:01:00Z' }))
    }
    await store.open('dm-1', request)
    await expect(store.edit('message-1', 'Без упоминания', 1, request, [])).resolves.toBe(true)
    expect(editPayload).not.toHaveProperty('mention_user_ids')
    expect(store.messages[0]?.mentionUserIds).toEqual([])
  })
})
