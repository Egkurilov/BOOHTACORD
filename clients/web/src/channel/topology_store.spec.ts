import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useTopologyStore } from './topology_store'

describe('channel topology store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('keeps topology empty and exposes a safe message when loading fails', async () => {
    const store = useTopologyStore()

    await store.refresh(async () => new Response('', { status: 401 }))

    expect(store.topology).toBeNull()
    expect(store.loading).toBe(false)
    expect(store.error).toContain('401')
  })
})
