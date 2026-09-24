import { createPinia, setActivePinia } from 'pinia'
import { describe, expect, it, vi } from 'vitest'

import { useMessageStore } from './message_store'

describe('TEXT retry scope', () => {
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
