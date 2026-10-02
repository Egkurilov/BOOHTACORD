import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const fixture = vi.hoisted(() => ({
  active: null as { channelId: string; leaseId: string; microphone: string; room: object; screenProfile: null } | null,
  join: vi.fn<() => Promise<{ channelId: string; leaseId: string; microphone: string; room: object; screenProfile: null }>>(),
  leave: vi.fn<() => Promise<void>>(),
  revoke: vi.fn<(id: string) => Promise<boolean>>(),
}))

vi.mock('./voice_session', () => ({
  VoiceSession: class {
    audioProcessing = { diagnostics: { supported: false } }
    screen = {}
    get active() { return fixture.active }
    async join() { fixture.active = await fixture.join(); return fixture.active }
    async leave() { await fixture.leave(); fixture.active = null }
    async revoke(id: string) { const result = await fixture.revoke(id); if (result) fixture.active = null; return result }
    participantCards = () => null
    remoteVoices = () => null
    screenViewer = () => null
    setAudioProcessing = vi.fn(async () => {})
    setConnectionObserver = vi.fn()
  },
}))

import { useVoiceConnectionStore } from './connection_store'

describe('voice connection revoked lease state', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    fixture.active = null
    fixture.join.mockReset().mockResolvedValue({ channelId: 'voice-1', leaseId: 'lease-1', microphone: 'MUTED', room: {}, screenProfile: null })
    fixture.leave.mockReset().mockResolvedValue(undefined)
    fixture.revoke.mockReset().mockResolvedValue(true)
  })

  it('preserves another active lease', async () => {
    const store = useVoiceConnectionStore()
    await store.join('voice-1')
    await expect(store.revokeLease('lease-other', 'KICK')).resolves.toBe(false)
    expect(store.active?.leaseId).toBe('lease-1')
    expect(fixture.revoke).not.toHaveBeenCalled()
  })

  it('shows the reason after local media teardown', async () => {
    const store = useVoiceConnectionStore()
    await store.join('voice-1')
    await expect(store.revokeLease('lease-1', 'CHANNEL_CLOSED')).resolves.toBe(true)
    expect(fixture.revoke).toHaveBeenCalledWith('lease-1')
    expect(store.active).toBeNull()
    expect(store.state).toBe('ERROR')
    expect(store.error).toContain('канал')
  })

  it('does not race a normal leave or logout with a second disconnect', async () => {
    let finish!: () => void
    fixture.leave.mockImplementation(() => new Promise<void>((resolve) => { finish = resolve }))
    const store = useVoiceConnectionStore()
    await store.join('voice-1')
    const leaving = store.leave()
    await expect(store.revokeLease('lease-1', 'LOGOUT')).resolves.toBe(false)
    expect(fixture.revoke).not.toHaveBeenCalled()
    finish()
    await leaving
    expect(store.active).toBeNull()
  })

  it('retries local teardown after a leaving room disconnect fails during session expiry', async () => {
    fixture.leave.mockRejectedValueOnce(new Error('room disconnect failed'))
    const store = useVoiceConnectionStore()
    await store.join('voice-1')
    const leaving = store.leave()
    await store.disconnectLocal('SESSION_REVOKED')
    await leaving
    expect(fixture.revoke).toHaveBeenCalledWith('lease-1')
    expect(store.active).toBeNull()
  })

  it('does not lose a matching server revocation during a failed normal leave', async () => {
    fixture.leave.mockRejectedValueOnce(new Error('room disconnect failed'))
    const store = useVoiceConnectionStore()
    await store.join('voice-1')
    const leaving = store.leave()
    await expect(store.revokeLease('lease-1', 'KICK')).resolves.toBe(false)
    await leaving
    expect(fixture.revoke).toHaveBeenCalledWith('lease-1')
    expect(store.active).toBeNull()
    expect(store.error).toContain('Администратор')
  })

})
