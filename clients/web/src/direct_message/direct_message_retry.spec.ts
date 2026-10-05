import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useDirectMessageStore } from './direct_message_store'

const serverMessage = (dm: string, id: string, clientId: string, body: string) => ({
  id, direct_message_id: dm, author_id: 'me', client_message_id: clientId,
  body, created_at: '2026-09-25T10:00:00Z', revision: 1, deleted: false, mention_user_ids: [],
})
const page = (messages: unknown[] = []) => new Response(JSON.stringify({ messages }))
const created = (dm: string, id: string, clientId: string, body: string) =>
  new Response(JSON.stringify(serverMessage(dm, id, clientId, body)))

describe('direct-message send retry', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('shows an optimistic row and retries the exact failed payload with its original client ID', async () => {
    const store = useDirectMessageStore()
    const posts: Record<string, unknown>[] = []
    let rejectFirst: ((error: Error) => void) | undefined
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'me', message_id: null }))
      if (init.method === 'GET') return page()
      const payload = JSON.parse(String(init.body)) as Record<string, unknown>
      posts.push(payload)
      if (posts.length === 1) return new Promise<Response>((_resolve, reject) => { rejectFirst = reject })
      return created('dm-a', 'message-a', 'client-a', 'Привет')
    }
    await store.open('dm-a', request)
    const sending = store.send('Привет', request, () => 'client-a', 'reply-a', 'me')
    expect(store.messages).toMatchObject([{ id: 'optimistic:client-a', sendStatus: 'sending', replyToId: 'reply-a' }])
    rejectFirst?.(new Error('network'))
    await expect(sending).resolves.toBe(false)
    expect(store.messages).toMatchObject([{ id: 'optimistic:client-a', sendStatus: 'failed' }])
    await expect(store.retry('client-a', request)).resolves.toBe(true)
    expect(posts).toHaveLength(2)
    expect(posts[1]).toEqual(posts[0])
    expect(posts[0]).toMatchObject({ client_message_id: 'client-a', body: 'Привет', reply_to_id: 'reply-a' })
    expect(store.messages).toMatchObject([{ id: 'message-a', clientMessageId: 'client-a' }])
    expect(store.messages).toHaveLength(1)
  })

  it('reconciles a lost response against server history and does not reuse an acknowledged ID', async () => {
    const store = useDirectMessageStore()
    let history: unknown[] = []
    let nextId = 0
    const posts: string[] = []
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'me', message_id: null }))
      if (init.method === 'GET') return page(history)
      const payload = JSON.parse(String(init.body)) as { client_message_id: string }
      posts.push(payload.client_message_id)
      if (posts.length === 1) throw new Error('response lost')
      return created('dm-a', 'message-new', payload.client_message_id, 'Привет')
    }
    await store.open('dm-a', request)
    await expect(store.send('Привет', request, () => `client-${++nextId}`, undefined, 'me')).resolves.toBe(false)
    history = [serverMessage('dm-a', 'message-old', 'client-1', 'Привет')]
    await store.refreshHistory(request)
    expect(store.messages).toMatchObject([{ id: 'message-old' }])
    expect(store.messages).toHaveLength(1)
    await expect(store.retry('client-1', request)).resolves.toBe(false)
    await expect(store.send('Привет', request, () => `client-${++nextId}`, undefined, 'me')).resolves.toBe(true)
    expect(posts).toEqual(['client-1', 'client-2'])
  })

  it('keeps a failed send scoped to its DM across navigation and never inserts it into another history', async () => {
    const store = useDirectMessageStore()
    let rejectSend: ((error: Error) => void) | undefined
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'me', message_id: null }))
      if (init.method === 'GET') return page(_input.includes('/dm-b/') ? [serverMessage('dm-b', 'message-b', 'client-b', 'B')] : [])
      return new Promise<Response>((_resolve, reject) => { rejectSend = reject })
    }
    await store.open('dm-a', request)
    const sending = store.send('A', request, () => 'client-a', undefined, 'me')
    await store.open('dm-b', request)
    rejectSend?.(new Error('network'))
    await expect(sending).resolves.toBe(false)
    expect(store.messages).toMatchObject([{ id: 'message-b' }])
    await store.open('dm-a', request)
    expect(store.messages).toMatchObject([{ id: 'optimistic:client-a', sendStatus: 'failed' }])
  })

  it('does not duplicate a pending row when refresh runs during an in-flight send', async () => {
    const store = useDirectMessageStore()
    let resolveSend: ((response: Response) => void) | undefined
    const request = async (_input: string, init: RequestInit) => init.method === 'GET'
      ? page()
      : new Promise<Response>((resolve) => { resolveSend = resolve })
    await store.open('dm-a', request)
    const sending = store.send('A', request, () => 'client-a', undefined, 'me')
    await store.refreshHistory(request)
    expect(store.messages).toMatchObject([{ id: 'optimistic:client-a', sendStatus: 'sending' }])
    expect(store.messages).toHaveLength(1)
    resolveSend?.(created('dm-a', 'message-a', 'client-a', 'A'))
    await expect(sending).resolves.toBe(true)
    expect(store.messages).toHaveLength(1)
  })

  it('uses a new ID when the failed draft changes while preserving retry for the original', async () => {
    const store = useDirectMessageStore()
    const posts: string[] = []
    const request = async (_input: string, init: RequestInit) => {
      if (_input.includes('/message-delivery/')) return new Response(JSON.stringify({ account_id: 'me', message_id: null }))
      if (init.method === 'GET') return page()
      const payload = JSON.parse(String(init.body)) as { client_message_id: string }
      posts.push(payload.client_message_id)
      throw new Error('network')
    }
    await store.open('dm-a', request)
    await store.send('Первое', request, () => 'client-1')
    await store.send('Второе', request, () => 'client-2')
    expect(posts).toEqual(['client-1', 'client-2'])
    expect(store.messages).toMatchObject([
      { clientMessageId: 'client-2', sendStatus: 'failed' },
      { clientMessageId: 'client-1', sendStatus: 'failed' },
    ])
    await store.retry('client-1', request)
    expect(posts).toEqual(['client-1', 'client-2', 'client-1'])
  })
})
