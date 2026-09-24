import { createPinia, defineStore, setActivePinia } from 'pinia'
import { ref } from 'vue'
import { describe, expect, it } from 'vitest'

import { clearAuthenticatedState } from './clear_authenticated_state'

describe('authenticated state boundary', () => {
  it('disposes account-bound stores so the next account never inherits DM and draft data', () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const usePrivate = defineStore('private-test', () => ({ dmBody: ref(''), draft: ref('') }))
    const before = usePrivate()
    before.dmBody = 'private conversation'
    before.draft = 'unfinished draft'

    clearAuthenticatedState(pinia)

    expect(pinia.state.value).toEqual({})
    expect(pinia._s.size).toBe(0)
    const after = usePrivate()
    expect(after).not.toBe(before)
    expect(after.dmBody).toBe('')
    expect(after.draft).toBe('')
  })
})
