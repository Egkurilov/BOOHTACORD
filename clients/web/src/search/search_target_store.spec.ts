import { createPinia, setActivePinia } from 'pinia'
import { describe, expect, it } from 'vitest'

import { useSearchTargetStore } from './search_target_store'

describe('search result navigation target', () => {
  it('preserves the selected message ID and clears only when that conversation closes', () => {
    setActivePinia(createPinia())
    const store = useSearchTargetStore()
    store.open({ kind: 'DIRECT_MESSAGE', conversationId: 'dm-2', messageId: 'old' })
    store.clearFor('CHANNEL', 'text-1')
    expect(store.target).toMatchObject({ conversationId: 'dm-2', messageId: 'old' })
    store.clearFor('DIRECT_MESSAGE', 'dm-2')
    expect(store.target).toBeNull()
  })
})
