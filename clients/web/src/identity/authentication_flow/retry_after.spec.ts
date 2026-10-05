import { describe, expect, it } from 'vitest'
import { AuthenticationRateLimitError, retryAfterSeconds } from './retry_after'
import { login } from '../auth_client'
import { completePasswordReset } from '../password_reset_client'

describe('manual authentication rate limit feedback', () => {
  it('accepts delta seconds and future HTTP date; rejects malformed values', () => {
    const now = Date.parse('Mon, 05 Oct 2026 12:00:00 GMT')
    expect(retryAfterSeconds('42', now)).toBe(42)
    expect(retryAfterSeconds('Mon, 05 Oct 2026 12:00:31 GMT', now)).toBe(31)
    expect(retryAfterSeconds('Mon, 05 Oct 2026 11:00:00 GMT', now)).toBe(0)
    for (const value of [null, '', '-5', 'garbage', '999999999999999999999999']) {
      expect(retryAfterSeconds(value, now)).toBeNull()
    }
  })
  it('includes Retry-After for login and password-reset without retrying transport', async () => {
    for (const operation of ['login', 'reset']) {
      let calls = 0
      async function request() { calls++; return new Response(null, { status: 429, headers: { 'retry-after': '42' } }) }
      await expect(operation === 'login' ? login({ login: 'member', password: 'secret' }, request)
        : completePasswordReset('private-token', 'secret', request)).rejects.toThrow('42 с.')
      expect(calls).toBe(1)
    }
  })
  it('uses safe fallback when header is absent', () => {
    expect(new AuthenticationRateLimitError(null).message).toContain('вручную')
  })
})
