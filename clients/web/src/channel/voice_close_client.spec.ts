import { describe, expect, it, vi } from 'vitest'

import { closeVoiceAdmission, VoiceCloseError } from './voice_close_client'

describe('VOICE close admission client', () => {
  it('posts the topology revision and parses a logical lease count', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'voice-1', revision: 9, revoked_leases: 2 })))
    await expect(closeVoiceAdmission('voice-1', 8, request)).resolves.toEqual({ id: 'voice-1', revision: 9, revokedLeases: 2 })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/voice-channels/voice-1/close-admission', {
      method: 'POST', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ expected_revision: 8 }),
    })
  })

  it('distinguishes forbidden and conflict and rejects malformed success', async () => {
    const denied = vi.fn().mockResolvedValue(new Response(null, { status: 403 }))
    const stale = vi.fn().mockResolvedValue(new Response(null, { status: 409 }))
    await expect(closeVoiceAdmission('voice-1', 8, denied)).rejects.toMatchObject({ status: 403 })
    await expect(closeVoiceAdmission('voice-1', 8, stale)).rejects.toBeInstanceOf(VoiceCloseError)
    const malformed = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'voice-1', revision: 9, revoked_leases: -1 })))
    await expect(closeVoiceAdmission('voice-1', 8, malformed)).rejects.toThrow('некоррект')
  })
})
