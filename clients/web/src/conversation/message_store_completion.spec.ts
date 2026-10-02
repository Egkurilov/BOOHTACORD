import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageStore } from './message_store'

const message = { id: 'message-1', channel_id: 'text-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-17T12:00:00Z', attachments: [], mention_user_ids: [] }

describe('TEXT send completion', () => {
  beforeEach(() => setActivePinia(createPinia()))

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
})
