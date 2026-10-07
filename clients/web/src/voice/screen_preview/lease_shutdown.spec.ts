import { describe, expect, it, vi } from 'vitest'

import { VoiceSession, type VoiceAdmission } from '../voice_session'

describe('screen preview lease shutdown', () => {
  it('waits for local preview invalidation before releasing the voice lease', async () => {
    const admission: VoiceAdmission = {
      acquire: vi.fn().mockResolvedValue({ id: 'lease-1', channelId: 'voice-1', transferred: false }),
      credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }),
      release: vi.fn().mockResolvedValue(undefined),
    }
    let finishInvalidation!: () => void
    const invalidating = new Promise<void>(resolve => { finishInvalidation = resolve })
    const stopScreenPreview = vi.fn(() => invalidating)
    const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn(), stopScreenPreview }
    const session = new VoiceSession(admission, async () => ({ room: room as never, microphone: 'MUTED' }))
    await session.join('voice-1')

    const leaving = session.leave()
    await vi.waitFor(() => expect(stopScreenPreview).toHaveBeenCalledOnce())
    expect(room.disconnect).not.toHaveBeenCalled()
    expect(admission.release).not.toHaveBeenCalled()
    finishInvalidation()
    await leaving
    expect(admission.release).toHaveBeenCalledWith('lease-1')
  })
})
