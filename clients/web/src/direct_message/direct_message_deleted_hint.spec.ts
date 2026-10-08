import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useDirectMessageStore } from './direct_message_store'

describe('direct-message deletion hints', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('retains a tombstone for an older message only in the selected DM', async () => {
    const store = useDirectMessageStore()
    const request = async () => new Response(JSON.stringify({ messages: [] }))
    await store.open('dm-1', request)
    store.applyDeletedHint('dm-1', 'older-message')
    expect(store.deletedMessageIds).toContain('older-message')
    await store.open('dm-2', request)
    expect(store.deletedMessageIds).toEqual([])
  })
})
