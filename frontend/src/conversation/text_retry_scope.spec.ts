import { createPinia, setActivePinia } from 'pinia'
import { describe, expect, it, vi } from 'vitest'

import { useMessageStore } from './message_store'

describe('TEXT retry scope', () => {
  it('acknowledges a delayed A send without inserting it into B history', async () => {
    setActivePinia(createPinia())
    const store = useMessageStore()
    let resolveSend!: (response: Response) => void
    const request = (path: string, init: RequestInit) => init.method === 'GET'
      ? Promise.resolve(new Response(JSON.stringify({ messages: path.includes('/b/') ? [{ id: 'message-b', channel_id: 'b', author_id: 'peer', client_message_id: 'client-b', body: 'B', revision: 1, created_at: '2026-09-25T10:00:00Z', deleted: false, attachments: [], mention_user_ids: [] }] : [] })))
      : new Promise<Response>((resolve) => { resolveSend = resolve })
    await store.open('a', request)
    const sending = store.send('A', request, () => 'client-a')
    await store.open('b', request)
    resolveSend(new Response(JSON.stringify({ id: 'message-a', channel_id: 'a', author_id: 'me', client_message_id: 'client-a', body: 'A', revision: 1, created_at: '2026-09-25T10:00:00Z', deleted: false, attachments: [], mention_user_ids: [] })))
    await expect(sending).resolves.toBe(true)
    expect(store.messages).toMatchObject([{ id: 'message-b' }])
  })
  it('does not insert or resend a failed A draft while B is open', async () => {
    setActivePinia(createPinia())
    const store = useMessageStore()
    const post = vi.fn().mockRejectedValue(new Error('network'))
    const request = async (path: string, init: RequestInit) => init.method === 'GET'
      ? new Response(JSON.stringify({ messages: [] }))
      : post(path, init)
    await store.open('a', request)
    await expect(store.send('A', request, () => 'client-a')).resolves.toBe(false)
    await store.open('b', request)
    await expect(store.retry('client-a', request)).resolves.toBe(false)
    expect(post).toHaveBeenCalledOnce()
    expect(store.messages).toEqual([])
  })
})
