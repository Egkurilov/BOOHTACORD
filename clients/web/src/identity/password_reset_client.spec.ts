import { describe, expect, it, vi } from 'vitest'

import { completePasswordReset, PasswordResetInvalidError } from './password_reset_client'

describe('password reset completion client', () => {
  it('posts token in JSON only and accepts 204 without reading a body', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))
    await completePasswordReset('opaque-secret', 'correct horse battery staple', request)

    expect(request).toHaveBeenCalledWith('/api/v1/auth/password-reset/complete', expect.objectContaining({
      method: 'POST', credentials: 'same-origin', cache: 'no-store', referrerPolicy: 'no-referrer',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ token: 'opaque-secret', password: 'correct horse battery staple' }),
    }))
    expect(request.mock.calls[0]?.[0]).not.toContain('opaque-secret')
  })

  it.each(['invalid', 'expired', 'reused'])('treats %s reset as the same unavailable-link error', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { code: 'VALIDATION_FAILED' } }), { status: 400 }))
    await expect(completePasswordReset('opaque-secret', 'correct horse battery staple', request)).rejects.toBeInstanceOf(PasswordResetInvalidError)
    await expect(completePasswordReset('opaque-secret', 'correct horse battery staple', request)).rejects.toThrow('Ссылка недействительна или срок её действия истёк')
  })

  it('does not reflect arbitrary server response text into the UI', async () => {
    const request = vi.fn().mockResolvedValue(new Response('opaque-secret', { status: 500 }))
    await expect(completePasswordReset('opaque-secret', 'correct horse battery staple', request)).rejects.toThrow('Не удалось изменить пароль')
  })
})
