import { readFileSync } from 'node:fs'
import { describe, expect, it, vi } from 'vitest'

import { expireWorkspaceSession } from './session_expiry_media'

describe('revoked session media teardown', () => {
  it('starts local LiveKit revocation without waiting for an HTTP lease release or blocking guest UI', async () => {
    let finish!: () => void
    const voice = { disconnectLocal: vi.fn(() => new Promise<void>((resolve) => { finish = resolve })) }
    const showGuest = vi.fn()

    expireWorkspaceSession(voice, showGuest)

    expect(voice.disconnectLocal).toHaveBeenCalledWith('SESSION_REVOKED')
    expect(showGuest).toHaveBeenCalledOnce()
    finish()
  })

  it('invalidates even a pending join with no active lease in the store', () => {
    const voice = { disconnectLocal: vi.fn(async () => undefined) }
    const showGuest = vi.fn()

    expireWorkspaceSession(voice, showGuest)

    expect(voice.disconnectLocal).toHaveBeenCalledWith('SESSION_REVOKED')
    expect(showGuest).toHaveBeenCalledOnce()
  })

  it('keeps the guest transition when local teardown fails', async () => {
    const voice = { disconnectLocal: vi.fn().mockRejectedValue(new Error('local disconnect failed')) }
    const showGuest = vi.fn()
    expireWorkspaceSession(voice, showGuest)
    await Promise.resolve()
    expect(showGuest).toHaveBeenCalledOnce()
  })

  it('uses the session-expired callback rather than ordinary WS disconnect to stop media', () => {
    const workspace = readFileSync(new URL('./WorkspaceApp.vue', import.meta.url), 'utf8')
    expect(workspace).toContain("expireWorkspaceSession(voiceConnection, () => emit('sessionExpired'))")
  })
})
