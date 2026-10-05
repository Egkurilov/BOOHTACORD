import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

type Active = { channelId: string; leaseId: string; microphone: string; room: object; screenProfile: null }
const joined: Active = { channelId: 'voice-1', leaseId: 'lease-1', microphone: 'MUTED', room: {}, screenProfile: null }
const fixture = vi.hoisted(() => ({
  active: null as Active | null,
  join: vi.fn<() => Promise<Active>>(),
  revoke: vi.fn<(id: string) => Promise<boolean>>(),
}))

vi.mock('./voice_session', () => ({
  VoiceSession: class {
    audioProcessing = { diagnostics: { supported: false } }
    screen = {}
    get active() { return fixture.active }
    async join() { fixture.active = await fixture.join(); return fixture.active }
    async leave() { fixture.active = null }
    async revoke(id: string) { const result = await fixture.revoke(id); if (result) fixture.active = null; return result }
    participantCards = () => null
    remoteVoices = () => null
    screenViewer = () => null
    setAudioProcessing = vi.fn(async () => {})
    setConnectionObserver = vi.fn()
  },
}))

import { useVoiceConnectionStore } from './connection_store'

describe('voice revocation during pending join', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    fixture.active = null
    fixture.join.mockReset()
    fixture.revoke.mockReset().mockResolvedValue(true)
  })

  function pendingJoin() {
    let finish!: (value: Active) => void
    fixture.join.mockImplementation(() => new Promise((resolve) => { finish = resolve }))
    const store = useVoiceConnectionStore()
    const joining = store.join('voice-1')
    return { store, joining, finish: () => finish(joined) }
  }

  it('invalidates an in-flight join before session-expiry guest navigation', async () => {
    const { store, joining, finish } = pendingJoin()
    await vi.waitFor(()=>expect(fixture.join).toHaveBeenCalledOnce())
    const cleanup = store.disconnectLocal('SESSION_REVOKED')
    finish()
    await joining
    await cleanup
    expect(fixture.revoke).toHaveBeenCalledWith('lease-1')
    expect(store.active).toBeNull()
  })

  it('applies a revocation that arrives while the matching lease is joining', async () => {
    const { store, joining, finish } = pendingJoin()
    await expect(store.revokeLease('lease-1', 'KICK')).resolves.toBe(false)
    finish()
    await joining
    expect(fixture.revoke).toHaveBeenCalledWith('lease-1')
    expect(store.active).toBeNull()
    expect(store.error).toContain('Администратор')
  })

  it('preserves a join when an unrelated lease was revoked during admission', async () => {
    const { store, joining, finish } = pendingJoin()
    await expect(store.revokeLease('lease-other', 'KICK')).resolves.toBe(false)
    finish()
    await joining
    expect(fixture.revoke).not.toHaveBeenCalled()
    expect(store.active?.leaseId).toBe('lease-1')
  })
})
