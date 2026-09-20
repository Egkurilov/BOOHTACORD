import { describe, expect, it, vi } from 'vitest'

import { acquireVoiceLease, issueLiveKitCredential, releaseVoiceLease } from './admission_client'

describe('voice admission client', () => {
  it('uses same-origin authenticated requests and does not persist a credential', async () => {
    const request = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'lease-1', channel_id: 'voice-1', transferred: false })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ url: 'wss://rtc.example', token: 'temporary', expires_at: '2026-09-17T12:00:00Z' })))

    await expect(acquireVoiceLease('voice-1', false, request)).resolves.toMatchObject({ id: 'lease-1' })
    await expect(issueLiveKitCredential('lease-1', request)).resolves.toMatchObject({ url: 'wss://rtc.example' })
    expect(request).toHaveBeenNthCalledWith(1, '/api/v1/voice/channels/voice-1/leases', expect.objectContaining({
      method: 'POST', credentials: 'same-origin', body: '{"transfer":false}',
    }))
    expect(request).toHaveBeenNthCalledWith(2, '/api/v1/voice/leases/lease-1/credential', expect.objectContaining({
      method: 'POST', credentials: 'same-origin',
    }))
  })

  it('releases the server-side lease through its idempotent endpoint', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))

    await expect(releaseVoiceLease('lease-1', request)).resolves.toBeUndefined()
    expect(request).toHaveBeenCalledWith('/api/v1/voice/leases/lease-1', expect.objectContaining({ method: 'DELETE' }))
  })

  it('exposes an active channel only to support an explicit transfer choice', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      error: { code: 'ACTIVE_VOICE_LEASE' }, active_channel_id: 'voice-elsewhere',
    }), { status: 409 }))

    await expect(acquireVoiceLease('voice-1', false, request)).rejects.toMatchObject({
      code: 'ACTIVE_VOICE_LEASE', activeChannelId: 'voice-elsewhere', status: 409,
    })
  })
})
