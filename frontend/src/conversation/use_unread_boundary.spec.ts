import { describe, expect, it, vi } from 'vitest'
import { effectScope, nextTick, ref } from 'vue'
import { useUnreadBoundary } from './use_unread_boundary'

describe('first unread boundary', () => {
  it('keeps the initial anchor while counts refresh, then unlocks the latest view', async () => {
    const id = ref('a')
    const first = ref<string | undefined>('a-1')
    const onLatest = vi.fn()
    const scope = effectScope()
    const state = scope.run(() => useUnreadBoundary(() => id.value, first, onLatest))!
    expect(state.unreadBoundary.value).toBe('a-1')
    first.value = undefined
    await nextTick()
    expect(state.unreadBoundary.value).toBe('a-1')
    state.showUnread()
    expect(state.unreadContextOpen.value).toBe(true)
    state.continueAtLatest()
    await nextTick()
    expect(state.readUnlocked.value).toBe(true)
    expect(onLatest).toHaveBeenCalledOnce()
    id.value = 'b'
    first.value = 'b-1'
    await nextTick()
    expect(state.readUnlocked.value).toBe(false)
    expect(state.unreadBoundary.value).toBe('b-1')
    scope.stop()
  })
})
