import { describe, expect, it, vi } from 'vitest'
import { loadOwnSessions, revokeOwnSession, revokeOtherSessions } from './client'
const account = '00000000-0000-4000-8000-000000000001'
const id = '00000000-0000-4000-8000-000000000002'
const session = { id, label: 'Вход в приложение', created_at: '2026-10-05T00:00:00Z', last_active_at: '2026-10-05T01:00:00Z', current: true }
describe('private own sessions API', () => {
  it('uses same-origin cookies and discards unexpected private fields', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ account_id: account, sessions: [{ ...session, token_digest: 'must-not-render' }], next_cursor: null })))
    const page = await loadOwnSessions(undefined, request)
    expect(page.accountId).toBe(account); expect(page.sessions[0]).not.toHaveProperty('token_digest')
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/me\/sessions$/), expect.objectContaining({ credentials: 'same-origin', cache: 'no-store', method: 'GET' }))
  })
  it('binds mutations to the account shown by the interface', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))
    await revokeOwnSession(account, id, request); await revokeOtherSessions(account, request)
    expect(request).toHaveBeenNthCalledWith(1, expect.stringMatching(new RegExp(`/me/sessions/${id}$`)), expect.objectContaining({ method: 'DELETE', headers: expect.objectContaining({ 'X-Account-ID': account }) }))
    expect(request).toHaveBeenNthCalledWith(2, expect.stringMatching(/\/me\/sessions\/revoke-others$/), expect.objectContaining({ method: 'POST', headers: expect.objectContaining({ 'X-Account-ID': account }) }))
  })
  it('rejects invalid public handles before sending a request', async () => {
    const request = vi.fn()
    await expect(revokeOwnSession(account, '../other-account', request)).rejects.toThrow()
    expect(request).not.toHaveBeenCalled()
  })
  it('preserves server conflict type without exposing raw payload', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { code: 'SESSION_ACCOUNT_CHANGED', message: 'Аккаунт изменился.' } }), { status: 409 }))
    await expect(revokeOtherSessions(account, request)).rejects.toMatchObject({ status: 409, code: 'SESSION_ACCOUNT_CHANGED' })
  })
})
