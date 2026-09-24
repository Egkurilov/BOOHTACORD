import { describe, expect, it, vi } from 'vitest'

import { VoiceSession, type VoiceAdmission } from './voice_session'

function admission(): VoiceAdmission {
  return {
    acquire: vi.fn(async () => ({ id: 'lease-1', channelId: 'voice-1', transferred: false })),
    credential: vi.fn(async () => ({ url: 'wss://rtc.test', token: 'temporary', expiresAt: '2026-09-25T00:00:00Z' })),
    release: vi.fn(async () => {}),
  }
}

describe('revoked voice lease local teardown', () => {
  it('disconnects the matching room without sending an already-revoked release request', async () => {
    const api = admission()
    const room = { disconnect: vi.fn(async () => {}), on: vi.fn() }
    const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))
    await session.join('voice-1')
    await expect(session.revoke('lease-other')).resolves.toBe(false)
    expect(room.disconnect).not.toHaveBeenCalled()
    await expect(session.revoke('lease-1')).resolves.toBe(true)
    expect(room.disconnect).toHaveBeenCalledOnce()
    expect(api.release).not.toHaveBeenCalled()
    expect(session.active).toBeNull()
  })
})
