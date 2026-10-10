import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageStore } from './message_store'

function message(id: number) {
  return { id: `message-${id}`, channel_id: 'text-1', author_id: 'user-1', client_message_id: `client-${id}`, body: `Текст ${id}`, revision: 1, created_at: new Date(Date.UTC(2026, 8, 17, 12, 0, id)).toISOString(), attachments: [], mention_user_ids: [] }
}

function page(from: number, through: number, nextCursor?: string): Response {
  const messages = Array.from({ length: from - through + 1 }, (_, index) => message(from - index))
  return new Response(JSON.stringify({ messages, ...(nextCursor ? { next_cursor: nextCursor } : {}) }))
}

describe('TEXT history across multiple pages and realtime refresh', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('retries an initial history failure without showing an end cursor', async () => {
    const store = useMessageStore()
    let attempts = 0
    const request = async () => {
      if (attempts++ === 0) throw new Error('Сеть недоступна')
      return page(2, 1)
    }

    await store.open('text-1', request)
    expect(store.historyLoaded).toBe(false)
    expect(store.error).toBe('Сеть недоступна')
    expect(store.retryableError).toBe(true)
    await store.refresh(request)
    expect(store.historyLoaded).toBe(true)
    expect(store.retryableError).toBe(false)
    expect(store.messages.map(({ id }) => id)).toEqual(['message-2', 'message-1'])
  })

  it('keeps a forbidden history failure distinct and does not offer a retry', async () => {
    const store = useMessageStore()
    await store.open('text-1', async () => new Response(JSON.stringify({ error: { code: 'FORBIDDEN' } }), { status: 403 }))
    expect(store.error).toBe('Нет доступа к этому действию.')
    expect(store.retryableError).toBe(false)
    expect(store.historyLoaded).toBe(false)
  })

  it('retains loaded messages as stale and exposes a deliberate retry after a 503', async () => {
    const store = useMessageStore()
    await store.open('text-1', async () => page(1, 1))
    await store.refresh(async () => new Response('{}', { status: 503 }))
    expect(store.messages.map(({ id }) => id)).toEqual(['message-1'])
    expect(store.historyLoaded).toBe(true)
    expect(store.error).toBe('Сервис временно не отвечает. Попробуйте позже.')
    expect(store.retryableError).toBe(true)
  })

  it('loads more than 100 messages through three pages without duplicates', async () => {
    const store = useMessageStore()
    const request = async (url: string) => {
      if (url.includes('before=message-22')) return page(22, 1)
      if (url.includes('before=message-71')) return page(71, 22, 'message-22')
      return page(120, 71, 'message-71')
    }

    await store.open('text-1', request)
    await expect(store.loadOlder(request)).resolves.toBe(true)
    await expect(store.loadOlder(request)).resolves.toBe(true)
    expect(store.messages).toHaveLength(120)
    expect(new Set(store.messages.map(({ id }) => id)).size).toBe(120)
    expect(store.messages[0]?.id).toBe('message-120')
    expect(store.messages.at(-1)?.id).toBe('message-1')
    expect(store.nextCursor).toBeUndefined()
  })

  it('preserves an older page loaded while a realtime refresh is in flight', async () => {
    const store = useMessageStore()
    let resolveRefresh: ((response: Response) => void) | undefined
    let latestCalls = 0
    const request = async (url: string) => {
      if (url.includes('before=')) return page(3, 2, 'message-2')
      if (latestCalls++ === 0) return page(5, 4, 'message-4')
      return new Promise<Response>((resolve) => { resolveRefresh = resolve })
    }

    await store.open('text-1', request)
    const refreshing = store.refresh(request)
    await store.loadOlder(request)
    resolveRefresh?.(page(6, 5, 'message-5'))
    await refreshing
    expect(store.messages.map(({ id }) => id)).toEqual(['message-6', 'message-5', 'message-4', 'message-3', 'message-2'])
    expect(store.nextCursor).toBe('message-2')
  })
})
