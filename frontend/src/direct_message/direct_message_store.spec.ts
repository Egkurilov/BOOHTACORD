import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useDirectMessageStore } from './direct_message_store'

const history = (id: string, directMessageId: string, body: string) => ({
  id, direct_message_id: directMessageId, author_id: 'user-2', client_message_id: `client-${id}`,
  body, created_at: '2026-09-18T10:00:00Z', revision: 1, deleted: false,
})

describe('direct-message store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('loads the private navigation list and the selected conversation history', async () => {
    const store = useDirectMessageStore()
    const request = async (input: string) => input.endsWith('/messages')
      ? new Response(JSON.stringify({ messages: [history('message-1', 'dm-1', 'Привет')] }))
      : new Response(JSON.stringify({ direct_messages: [{ id: 'dm-1', other_participant_id: 'user-2', other_participant_display_name: 'Лера', created_at: '2026-09-18T09:00:00Z', unread_count: 1 }] }))

    await store.refreshNavigation(request)
    await store.open('dm-1', request)

    expect(store.directMessages).toMatchObject([{ id: 'dm-1', unreadCount: 1 }])
    expect(store.directMessageId).toBe('dm-1')
    expect(store.messages).toMatchObject([{ id: 'message-1', body: 'Привет' }])
  })

  it('does not replace the currently selected DM with a delayed history response', async () => {
    const store = useDirectMessageStore()
    let resolveFirst: ((response: Response) => void) | undefined
    const request = (input: string) => input.includes('/dm-a/messages')
      ? new Promise<Response>((resolve) => { resolveFirst = resolve })
      : Promise.resolve(new Response(JSON.stringify({ messages: [history('message-b', 'dm-b', 'B')] })))

    const firstOpen = store.open('dm-a', request)
    await Promise.resolve()
    await store.open('dm-b', request)
    resolveFirst?.(new Response(JSON.stringify({ messages: [history('message-a', 'dm-a', 'A')] })))
    await firstOpen

    expect(store.directMessageId).toBe('dm-b')
    expect(store.messages).toMatchObject([{ id: 'message-b' }])
  })

  it('clears a selected DM and invalidates an outstanding history request', async () => {
    const store = useDirectMessageStore()
    let resolveHistory: ((response: Response) => void) | undefined
    const opening = store.open('dm-1', () => new Promise<Response>((resolve) => { resolveHistory = resolve }))

    await Promise.resolve()
    store.close()
    resolveHistory?.(new Response(JSON.stringify({ messages: [] })))
    await opening

    expect(store.directMessageId).toBeNull()
    expect(store.messages).toEqual([])
  })

  it('prepends a server-created message only to the still-selected DM', async () => {
    const store = useDirectMessageStore()
    const request = async (_input: string, init: RequestInit) => init.method === 'GET'
      ? new Response(JSON.stringify({ messages: [] }))
      : new Response(JSON.stringify({ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-18T10:00:00Z', reply_to_id: 'message-0' }))

    await store.open('dm-1', request)
    await expect(store.send('Привет', request, () => 'client-1', 'message-0')).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ id: 'message-1', replyToId: 'message-0', deleted: false }])
  })

  it('immediately masks only the selected message after an author-delete', async () => {
    const store = useDirectMessageStore()
    const request = async (_input: string, init: RequestInit) => init.method === 'GET'
      ? new Response(JSON.stringify({ messages: [history('message-1', 'dm-1', 'Привет')] }))
      : new Response(null, { status: 204 })

    await store.open('dm-1', request)
    await expect(store.remove('message-1', request)).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ body: '', deleted: true, revision: 2 }])
  })

  it('does not insert a delayed send after moving to another DM', async () => {
    const store = useDirectMessageStore()
    let resolveSend: ((response: Response) => void) | undefined
    const request = (input: string, init: RequestInit) => {
      if (init.method === 'POST') return new Promise<Response>((resolve) => { resolveSend = resolve })
      return Promise.resolve(new Response(JSON.stringify({ messages: input.includes('/dm-b/') ? [history('message-b', 'dm-b', 'B')] : [] })))
    }

    await store.open('dm-a', request)
    const sending = store.send('A', request, () => 'client-a')
    await Promise.resolve()
    await store.open('dm-b', request)
    resolveSend?.(new Response(JSON.stringify({ id: 'message-a', direct_message_id: 'dm-a', author_id: 'user-1', client_message_id: 'client-a', body: 'A', revision: 1, created_at: '2026-09-18T10:00:00Z' })))

    await expect(sending).resolves.toBe(false)
    expect(store.directMessageId).toBe('dm-b')
    expect(store.messages).toMatchObject([{ id: 'message-b' }])
  })
})
