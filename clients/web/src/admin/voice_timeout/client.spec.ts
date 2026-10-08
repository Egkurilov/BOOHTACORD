import { describe, expect, it, vi } from 'vitest'
import { voiceTimeout } from './client'

const inactive = { active: false, revoked_leases: 0, revocation_pending: true }
describe('voice timeout wire contract', () => {
  it('uses only selected account cookie routes and bounded PUT payload', async () => {
    const request = vi.fn().mockImplementation(async () => new Response(JSON.stringify(inactive)))
    const input = { expires_at: '2026-10-09T10:00:00Z', reason_code: 'SPAM' as const }
    await voiceTimeout('member/id', 'GET', undefined, undefined, request)
    await voiceTimeout('member/id', 'PUT', input, undefined, request)
    await voiceTimeout('member/id', 'DELETE', undefined, undefined, request)
    expect(request.mock.calls[0][0]).toMatch(/\/accounts\/member%2Fid\/voice-timeout$/)
    expect(request.mock.calls[1][0]).toMatch(/\/admin\/accounts\/member%2Fid\/voice-timeout$/)
    expect(request.mock.calls[1][1]).toMatchObject({ credentials: 'same-origin', method: 'PUT', body: JSON.stringify(input) })
    expect(request.mock.calls[2][1]).toMatchObject({ credentials: 'same-origin', method: 'DELETE' })
  })
  it('rejects missing expiry, unbounded reasons, malformed counts or inactive private metadata', async () => {
    for (const state of [{ ...inactive, active: true }, { ...inactive, revoked_leases: -1 },
      { ...inactive, reason_code: 'SPAM' }, { ...inactive, active: true, expires_at: 'invalid', reason_code: 'SPAM' },
      { ...inactive, active: true, expires_at: '2026-10-09T10:00:00Z', reason_code: 'private text' }]) {
      await expect(voiceTimeout('member', 'GET', undefined, undefined,
        async () => new Response(JSON.stringify(state)))).rejects.toThrow('Некорректное состояние')
    }
  })
  it('never echoes unknown server text or reports success on forbidden mutation', async () => {
    await expect(voiceTimeout('member', 'DELETE', undefined, undefined,
      async () => new Response('private server secret', { status: 403 }))).rejects.toThrow('Нет прав')
  })
})
