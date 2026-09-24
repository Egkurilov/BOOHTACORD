import { describe, expect, it, vi } from 'vitest'

import { logout } from './logout_client'

describe('logout client', () => {
  it('revokes the cookie session with an empty same-origin POST; repeating 204 is safe', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))

    await logout(request)
    await logout(request)

    expect(request).toHaveBeenCalledTimes(2)
    expect(request).toHaveBeenCalledWith('/api/v1/auth/logout', {
      method: 'POST', credentials: 'same-origin', headers: { accept: 'application/json' },
    })
  })

  it('keeps a server revocation failure distinct from a successful logout', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 500 }))
    await expect(logout(request)).rejects.toThrow('Сервер не завершил сессию (500)')
  })

  it('reports a network failure without treating it as a completed logout', async () => {
    const request = vi.fn().mockRejectedValue(new TypeError('offline'))
    await expect(logout(request)).rejects.toThrow('Нет связи с сервером')
  })
})
