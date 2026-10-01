import { describe, expect, it, vi } from 'vitest'

import { VoiceSession, type VoiceAdmission } from './voice_session'

describe('local voice release before logout', () => {
  it('clears the locally disconnected room even if remote lease release fails', async () => {
    const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
    const admission: VoiceAdmission = {
      acquire: vi.fn().mockResolvedValue({ id: 'lease-1', channelId: 'voice-1', transferred: false }),
      credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.test', token: 'temporary', expiresAt: '2026-09-25T00:00:00Z' }),
      release: vi.fn().mockRejectedValue(new Error('lease request failed')),
    }
    const session = new VoiceSession(admission, async () => ({ room: room as never, microphone: 'PUBLISHED' }))
    await session.join('voice-1')

    await expect(session.leave()).rejects.toThrow('lease request failed')

    expect(room.disconnect).toHaveBeenCalledOnce()
    expect(session.active).toBeNull()
  })
})
