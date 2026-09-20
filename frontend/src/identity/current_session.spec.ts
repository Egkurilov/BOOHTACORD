import { describe, expect, it, vi } from 'vitest'

import { loadCurrentSession } from './current_session'

describe('current session client', () => {
  it('uses the authenticated same-origin session endpoint', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ account_id: 'user-1', role: 'MEMBER' })))

    await expect(loadCurrentSession(request)).resolves.toEqual({ accountId: 'user-1', role: 'MEMBER' })
    expect(request).toHaveBeenCalledWith('/api/v1/auth/session', expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('treats a public anonymous session response as a guest state', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ authenticated: false })))

    await expect(loadCurrentSession(request)).resolves.toBeNull()
  })
})
