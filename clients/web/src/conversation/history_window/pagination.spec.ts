import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageStore } from '../message_store'

function row(id: number) {
  return { id: `message-${id}`, channel_id: 'text-1', author_id: 'user-1', client_message_id: `client-${id}`, body: `Text ${id}`, revision: 1, created_at: new Date(Date.parse('2026-09-17T12:00:00Z') + id * 1000).toISOString(), attachments: [], mention_user_ids: [] }
}

function page(messages: ReturnType<typeof row>[], nextCursor?: string): Response {
  return new Response(JSON.stringify({ messages, ...(nextCursor ? { next_cursor: nextCursor } : {}) }))
}

describe('bounded history paging integration', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('keeps the visible anchor and pages reversibly across evicted edges', async () => {
    const store = useMessageStore(), urls: string[] = []
    const request = async (url: string) => {
      urls.push(url)
      if (url.includes('after=message-580')) return page(Array.from({ length: 20 }, (_, index) => row(581 + index)))
      if (url.includes('before=')) return page(Array.from({ length: 20 }, (_, index) => row(100 - index)), 'message-81')
      return page(Array.from({ length: 500 }, (_, index) => row(600 - index)), 'message-101')
    }

    await store.open('text-1', request)
    store.setHistoryAnchor('message-300')
    expect(store.messages).toHaveLength(500)
    expect(store.nextCursor).toBe('message-101')

    await expect(store.loadOlder(request)).resolves.toBe(true)
    expect(urls[1]).toContain('before=message-101')
    expect(store.messages).toHaveLength(500)
    expect(store.messages.map(({ id }) => id)).toContain('message-300')
    expect(store.nextCursor).toBe('message-81')
    expect(store.newerCursor).toBe('message-580')

    await expect(store.loadNewer(request)).resolves.toBe(true)
    expect(urls[2]).toContain('after=message-580')
    expect(store.messages).toHaveLength(500)
    expect(store.messages.map(({ id }) => id)).toContain('message-300')
    expect(store.messages.map(({ id }) => id)).toContain('message-600')
    expect(store.nextCursor).toBe('message-101')
  })
})
