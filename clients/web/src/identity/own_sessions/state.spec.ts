import { describe, expect, it, vi } from 'vitest'
import { createOwnSessionsState } from './state'
const current = { id: 'current', label: 'Вход', createdAt: '2026-10-05', lastActiveAt: '2026-10-05', current: true }
const other = { ...current, id: 'other', current: false }
const page = { accountId: 'A', sessions: [current, other], nextCursor: null }
describe('own sessions account lifecycle', () => {
  it('never applies a stale list after account change', async () => {
    let resolve!: (value: typeof page) => void
    const api = { read: vi.fn(() => new Promise<typeof page>(done => { resolve = done })), revoke: vi.fn(), revokeOthers: vi.fn() }
    const state = createOwnSessionsState(api)
    state.setAccount('A'); const pending = state.refresh(); state.setAccount('B'); resolve(page); await pending
    expect(state.items.value).toEqual([]); expect(state.error.value).toBeNull()
  })
  it('rejects a response belonging to a changed browser cookie owner', async () => {
    const state = createOwnSessionsState({ read: async () => ({ ...page, accountId: 'B' }), revoke: vi.fn(), revokeOthers: vi.fn() })
    state.setAccount('A'); await state.refresh()
    expect(state.items.value).toEqual([]); expect(state.error.value).toMatch(/Аккаунт/)
  })
  it('protects the current row and binds revoke-others to the owner', async () => {
    const api = { read: vi.fn().mockResolvedValue(page), revoke: vi.fn(), revokeOthers: vi.fn().mockResolvedValue(undefined) }
    const state = createOwnSessionsState(api); state.setAccount('A'); await state.refresh()
    await state.revoke(current.id); expect(api.revoke).not.toHaveBeenCalled()
    await state.revokeOthers(); expect(api.revokeOthers).toHaveBeenCalledWith('A')
  })
  it('invalidates pending callbacks when the screen is closed', async () => {
    const state = createOwnSessionsState({ read: async () => page, revoke: vi.fn(), revokeOthers: vi.fn() })
    state.setAccount('A'); const pending = state.refresh(); state.close(); await pending
    expect(state.items.value).toEqual([]); expect(state.busy.value).toBe(false)
  })
})
