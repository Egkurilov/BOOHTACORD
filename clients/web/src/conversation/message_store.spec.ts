import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageStore } from './message_store'

const message = { id: 'message-1', channel_id: 'text-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-17T12:00:00Z', attachments: [], mention_user_ids: [] }

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

  it('sends an attachment-only message but still rejects an empty draft without files', async () => {
    const store = useMessageStore()
    const payloads: Record<string, unknown>[] = []
    const attachment = { id: 'attachment-image', originalName: 'clipboard.png', sizeBytes: 4 }
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'user-1', message_id: null }))
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [] }))
      const payload = JSON.parse(String(init.body)) as Record<string, unknown>
      payloads.push(payload)
      return new Response(JSON.stringify({
        ...message,
        body: '',
        attachments: [{ id: attachment.id, original_name: attachment.originalName, byte_size: attachment.sizeBytes }],
      }))
    }

    await store.open('text-1', request)
    await expect(store.send('', request, () => 'client-image')).resolves.toBe(false)
    await expect(store.send('', request, () => 'client-image', undefined, [attachment])).resolves.toBe(true)

    expect(payloads).toMatchObject([{ body: '', attachment_ids: ['attachment-image'] }])
    expect(store.messages).toMatchObject([{ body: '', attachments: [attachment] }])
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
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'user-1', message_id: null }))
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

  it('retries with the original mention IDs even after an uncertain response', async () => {
    const store = useMessageStore()
    const payloads: unknown[] = []
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'user-1', message_id: null }))
      if (init.method === 'GET') return new Response(JSON.stringify({ messages: [] }))
      payloads.push(JSON.parse(String(init.body)))
      if (payloads.length === 1) throw new Error('Сеть недоступна')
      return new Response(JSON.stringify({ ...message, mention_user_ids: ['user-2'] }))
    }
    await store.open('text-1', request)
    await expect(store.send('Привет', request, () => 'client-1', undefined, [], 'user-1', ['user-2'])).resolves.toBe(false)
    await expect(store.retry('client-1', request)).resolves.toBe(true)
    expect(payloads).toMatchObject([
      { client_message_id: 'client-1', mention_user_ids: ['user-2'] },
      { client_message_id: 'client-1', mention_user_ids: ['user-2'] },
    ])
  })

  it('uses a new id when the failed draft changes', async () => {
    const store = useMessageStore()
    const sentIds: string[] = []
    let attempt = 0
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'user-1', message_id: null }))
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

})
