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

  it('shows an optimistic message and retains it as failed when acknowledgement is lost', async () => {
    const store = useMessageStore()
    let rejectPost: ((cause: Error) => void) | undefined
    const request = async (_input: string, init: RequestInit) => init.method === 'GET'
      ? new Response(JSON.stringify({ messages: [] }))
      : new Promise<Response>((_resolve, reject) => { rejectPost = reject })

    await store.open('text-1', request)
    const sending = store.send('Привет', request, () => 'client-1', undefined, [], 'user-1')
    expect(store.messages).toMatchObject([{ id: 'optimistic:client-1', body: 'Привет', clientMessageId: 'client-1', sendStatus: 'sending' }])
    rejectPost?.(new Error('Сеть недоступна'))
    await expect(sending).resolves.toBe(false)
    expect(store.messages).toMatchObject([{ id: 'optimistic:client-1', sendStatus: 'failed' }])
  })

  it('retries an uncertain send with the same id and replaces its optimistic row', async () => {
    const store = useMessageStore()
    let attempt = 0
    const request = async (_input: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [] }))
      if (attempt++ === 0) throw new Error('Сеть недоступна')
      return new Response(JSON.stringify(message))
    }

    await store.open('text-1', request)
    await expect(store.send('Привет', request, () => 'client-1', undefined, [], 'user-1')).resolves.toBe(false)
    await expect(store.retry('client-1', request)).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ id: 'message-1', clientMessageId: 'client-1' }])
    expect(store.messages[0]).not.toHaveProperty('sendStatus')
    expect(store.messages).toHaveLength(1)
  })

  it('uses a new id when the failed draft changes', async () => {
    const store = useMessageStore()
    const sentIds: string[] = []
    let attempt = 0
    const request = async (_input: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [] }))
      const payload = JSON.parse(String(init.body)) as { client_message_id: string }
      sentIds.push(payload.client_message_id)
      if (attempt++ === 0) throw new Error('Сеть недоступна')
      return new Response(JSON.stringify({ ...message, id: 'message-2', client_message_id: payload.client_message_id, body: 'Изменено' }))
    }
    let nextId = 0

    await store.open('text-1', request)
    await expect(store.send('Привет', request, () => `client-${++nextId}`, undefined, [], 'user-1')).resolves.toBe(false)
    await expect(store.send('Изменено', request, () => `client-${++nextId}`, undefined, [], 'user-1')).resolves.toBe(true)
    expect(sentIds).toEqual(['client-1', 'client-2'])
  })

  it('reconciles a lost acknowledgement with server history after returning to the channel', async () => {
    const store = useMessageStore()
    let postMayHaveCommitted = false
    const sentIds: string[] = []
    const request = async (input: string, init: RequestInit) => {
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: input.includes('text-1') && postMayHaveCommitted ? [message] : [] }))
      const payload = JSON.parse(String(init.body)) as { client_message_id: string }
      sentIds.push(payload.client_message_id)
      if (postMayHaveCommitted) return new Response(JSON.stringify(message))
      postMayHaveCommitted = true
      throw new Error('Подтверждение потеряно')
    }

    await store.open('text-1', request)
    await expect(store.send('Привет', request, () => 'client-1', undefined, [], 'user-1')).resolves.toBe(false)
    await store.open('text-2', request)
    await store.open('text-1', request)
    expect(store.messages).toMatchObject([{ id: 'message-1', clientMessageId: 'client-1' }])
    await expect(store.send('Привет', request, () => 'client-2', undefined, [], 'user-1')).resolves.toBe(true)
    expect(sentIds).toEqual(['client-1', 'client-1'])
    expect(store.messages).toHaveLength(1)
  })

  it('keeps a sent message when the initial history request completes later', async () => {
    const store = useMessageStore()
    let resolveHistory: ((response: Response) => void) | undefined
    const request = async (_input: string, init: RequestInit) => init.method === 'GET'
      ? new Promise<Response>((resolve) => { resolveHistory = resolve })
      : new Response(JSON.stringify(message))

    const opening = store.open('text-1', request)
    await expect(store.send('Привет', request, () => 'client-1', undefined, [], 'user-1')).resolves.toBe(true)
    resolveHistory?.(new Response(JSON.stringify({ messages: [] })))
    await opening
    expect(store.messages).toMatchObject([{ id: 'message-1', clientMessageId: 'client-1' }])
    expect(store.messages).toHaveLength(1)
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
