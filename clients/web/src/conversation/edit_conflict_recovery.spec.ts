import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useDirectMessageStore } from '../direct_message/direct_message_store'
import { useMessageStore } from './message_store'

const text = (id: string, revision: number) => ({ id, channel_id: 'text-a', author_id: 'me', client_message_id: `client-${id}`,
  body: `Текст ${id}`, revision, created_at: '2026-09-25T10:00:00Z', deleted: false, attachments: [], mention_user_ids: [] })
const dm = (id: string, revision: number) => ({ id, direct_message_id: 'dm-a', author_id: 'me', client_message_id: `client-${id}`,
  body: `Текст ${id}`, revision, created_at: '2026-09-25T10:00:00Z', deleted: false, attachments: [], mention_user_ids: [] })

describe('edit conflict recovery for loaded older messages', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('retrieves the current TEXT revision without losing the loaded window', async () => {
    const store = useMessageStore()
    let oldRevision = 1
    const patch = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ error: { code: 'CONFLICT' } }), { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ...text('old', 3), body: 'Мой черновик' })))
    const request = async (path: string, init: RequestInit) => init.method === 'PATCH'
      ? patch(path, init)
      : new Response(JSON.stringify(path.includes('before=')
        ? { messages: [text('old', oldRevision)] }
        : { messages: [text('new', 1)], next_cursor: 'cursor' }))
    await store.open('text-a', request)
    await store.loadOlder(request)
    expect(await store.editWithResult('old', 'Мой черновик', 1, request)).toMatchObject({ kind: 'conflict' })
    oldRevision = 2
    await expect(store.refreshMessage('old', request)).resolves.toMatchObject({ revision: 2 })
    expect(store.messages.find(({ id }) => id === 'old')).toMatchObject({ revision: 2 })
    expect(store.messages).toHaveLength(2)
    await expect(store.editWithResult('old', 'Мой черновик', 2, request)).resolves.toEqual({ kind: 'saved' })
    expect(JSON.parse(String(patch.mock.calls[1]?.[1].body))).toMatchObject({ expected_revision: 2, body: 'Мой черновик' })
  })

  it('retrieves a changed DM revision through the participant-scoped history', async () => {
    const store = useDirectMessageStore()
    let oldRevision = 1
    const patch = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ error: { code: 'CONFLICT' } }), { status: 409 }))
    const request = async (path: string, init: RequestInit) => init.method === 'PATCH'
      ? patch(path, init)
      : new Response(JSON.stringify(path.includes('before=')
        ? { messages: [dm('old', oldRevision)] }
        : { messages: [dm('new', 1)], next_cursor: 'cursor' }))
    await store.open('dm-a', request)
    await store.loadOlder(request)
    expect(await store.editWithResult('old', 'Мой черновик', 1, request)).toMatchObject({ kind: 'conflict' })
    oldRevision = 2
    await expect(store.refreshMessage('old', request)).resolves.toMatchObject({ revision: 2 })
    expect(store.messages.find(({ id }) => id === 'old')).toMatchObject({ revision: 2 })
    expect(store.messages).toHaveLength(2)
  })
})
