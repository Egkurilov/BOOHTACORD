import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useDirectMessageStore } from './direct_message_store'

function message(id: number) {
  return { id: `message-${id}`, direct_message_id: 'dm-1', author_id: 'user-2', client_message_id: `client-${id}`, body: `Текст ${id}`, revision: 1, deleted: false, created_at: new Date(Date.UTC(2026, 8, 18, 10, 0, id)).toISOString() }
}

function page(from: number, through: number, nextCursor?: string): Response {
  const messages = Array.from({ length: from - through + 1 }, (_, index) => message(from - index))
  return new Response(JSON.stringify({ messages, ...(nextCursor ? { next_cursor: nextCursor } : {}) }))
}

describe('DM history across multiple pages and concurrent refresh', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('loads more than 100 private messages across three pages', async () => {
    const store = useDirectMessageStore()
    const request = async (url: string) => {
      if (url.includes('before=message-22')) return page(22, 1)
      if (url.includes('before=message-71')) return page(71, 22, 'message-22')
      return page(120, 71, 'message-71')
    }

    await store.open('dm-1', request)
    await store.loadOlder(request)
    await store.loadOlder(request)
    expect(store.messages).toHaveLength(120)
    expect(new Set(store.messages.map(({ id }) => id)).size).toBe(120)
    expect(store.messages[0]?.id).toBe('message-120')
    expect(store.messages.at(-1)?.id).toBe('message-1')
    expect(store.nextCursor).toBeUndefined()
  })

  it('does not move the cursor backwards when realtime refresh completes after an older page', async () => {
    const store = useDirectMessageStore()
    let resolveRefresh: ((response: Response) => void) | undefined
    let latestCalls = 0
    const request = async (url: string) => {
      if (url.includes('before=')) return page(3, 2, 'message-2')
      if (latestCalls++ === 0) return page(5, 4, 'message-4')
      return new Promise<Response>((resolve) => { resolveRefresh = resolve })
    }

    await store.open('dm-1', request)
    const refreshing = store.refreshHistory(request)
    await store.loadOlder(request)
    resolveRefresh?.(page(6, 5, 'message-5'))
    await refreshing
    expect(store.messages.map(({ id }) => id)).toEqual(['message-6', 'message-5', 'message-4', 'message-3', 'message-2'])
    expect(store.nextCursor).toBe('message-2')
  })

  it('rejects an older response after the selected DM closes', async () => {
    const store = useDirectMessageStore()
    let resolveOlder: ((response: Response) => void) | undefined
    const request = async (url: string) => url.includes('before=')
      ? new Promise<Response>((resolve) => { resolveOlder = resolve })
      : page(3, 2, 'message-2')

    await store.open('dm-1', request)
    const older = store.loadOlder(request)
    store.close()
    resolveOlder?.(page(1, 1))
    await expect(older).resolves.toBe(false)
    expect(store.messages).toEqual([])
    expect(store.nextCursor).toBeUndefined()
    expect(store.olderLoading).toBe(false)
  })
})
