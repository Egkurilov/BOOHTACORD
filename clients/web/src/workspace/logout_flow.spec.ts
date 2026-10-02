import { readFileSync } from 'node:fs'
import { describe, expect, it, vi } from 'vitest'

import { useWorkspaceLogout } from './logout_flow'

function ports() {
  const calls: string[] = []
  return {
    calls,
    stopMedia: vi.fn(async () => { calls.push('media') }),
    mediaActive: vi.fn(() => false),
    revoke: vi.fn(async () => { calls.push('revoke') }),
    disconnectRealtime: vi.fn(() => { calls.push('realtime') }),
    clearState: vi.fn(() => { calls.push('clear') }),
    showGuest: vi.fn(() => { calls.push('guest') }),
  }
}

describe('workspace logout', () => {
  it('stops local media before revocation, then clears realtime and account data before guest UI', async () => {
    const actions = ports()
    const logout = useWorkspaceLogout(actions)

    await logout.signOut()

    expect(actions.calls).toEqual(['media', 'revoke', 'realtime', 'clear', 'guest'])
    expect(logout.error.value).toBeNull()
  })

  it('keeps the authenticated workspace and private stores if the server fails', async () => {
    const actions = ports()
    actions.revoke.mockRejectedValueOnce(new Error('Сервер не завершил сессию (500).'))
    const logout = useWorkspaceLogout(actions)

    await logout.signOut()

    expect(logout.error.value).toContain('500')
    expect(actions.disconnectRealtime).not.toHaveBeenCalled()
    expect(actions.clearState).not.toHaveBeenCalled()
    expect(actions.showGuest).not.toHaveBeenCalled()
  })

  it('does not claim logout while local media is still active', async () => {
    const actions = ports()
    actions.mediaActive.mockReturnValue(true)
    const logout = useWorkspaceLogout(actions)
    await logout.signOut()
    expect(actions.revoke).not.toHaveBeenCalled()
    expect(logout.error.value).toContain('голосовое соединение')
  })

  it('exposes a profile action and sends the successful outcome to App guest state', () => {
    const profile = readFileSync(new URL('../identity/ProfileSettings.vue', import.meta.url), 'utf8')
    const workspace = readFileSync(new URL('./WorkspaceApp.vue', import.meta.url), 'utf8')
    const app = readFileSync(new URL('../App.vue', import.meta.url), 'utf8')

    expect(profile).toContain('Выйти из аккаунта')
    expect(profile).toContain("emit('logout')")
    expect(workspace).toContain('@logout="signOut"')
    expect(workspace).toContain("emit('loggedOut')")
    expect(app).toContain('@logged-out="finishLogout"')
    expect(app).toContain("state.value = 'guest'")
  })
})
