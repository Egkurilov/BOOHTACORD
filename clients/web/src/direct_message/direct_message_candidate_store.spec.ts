import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useDirectMessageCandidateStore } from './direct_message_candidate_store'

describe('direct-message candidate store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('replaces the first page and appends only the next cursor page', async () => {
    const store = useDirectMessageCandidateStore()
    const request = async (input: string) => input.includes('after=user-2')
      ? new Response(JSON.stringify({ candidates: [{ id: 'user-3', display_name: 'Илья' }] }))
      : new Response(JSON.stringify({ candidates: [{ id: 'user-2', display_name: 'Лера' }], next_after: 'user-2' }))

    await store.refresh(request)
    await store.loadNext(request)

    expect(store.candidates).toEqual([{ id: 'user-2', displayName: 'Лера' }, { id: 'user-3', displayName: 'Илья' }])
    expect(store.nextAfter).toBeUndefined()
  })

  it('returns the opened pair identifier', async () => {
    const store = useDirectMessageCandidateStore()
    const request = async () => new Response(JSON.stringify({ id: 'dm-1', participant_one_id: 'user-1', participant_two_id: 'user-2', created_at: '2026-09-18T10:00:00Z' }))

    await expect(store.open('user-2', request)).resolves.toBe('dm-1')
    expect(store.opening).toBe(false)
    expect(store.error).toBeNull()
  })

  it('explains when a listed account became unavailable before opening', async () => {
    const store = useDirectMessageCandidateStore()
    const request = async () => new Response(JSON.stringify({ error: { code: 'NOT_FOUND' } }), { status: 404 })

    await expect(store.open('user-2', request)).resolves.toBeNull()
    expect(store.error).toBe('Участник больше недоступен. Обновите список.')
  })
})
