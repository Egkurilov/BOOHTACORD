import { describe, expect, it, vi } from 'vitest'
import { createPasswordResetLink, kickVoiceParticipant, listAdminAccounts, listAuditEvents, updateAdminAccount } from './admin_directory_client'

describe('administrator directory API client', () => {
  it('loads accounts and audit summaries over the current session', async () => {
    const request = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ accounts: [], next_cursor: 'cursor' }), { status: 200 })).mockResolvedValueOnce(new Response(JSON.stringify({ events: [], next_cursor: '10' }), { status: 200 }))
    await expect(listAdminAccounts(undefined, request)).resolves.toEqual({ accounts: [], next_cursor: 'cursor' })
    await expect(listAuditEvents(undefined, request)).resolves.toEqual({ events: [], next_cursor: '10' })
    expect(request).toHaveBeenNthCalledWith(1, expect.stringMatching(/\/admin\/accounts\?limit=100$/), expect.objectContaining({ credentials: 'same-origin' }))
    expect(request).toHaveBeenNthCalledWith(2, expect.stringMatching(/\/admin\/audit\?limit=100$/), expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('changes only the selected account role and blocked state', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ account_id: 'account-1', role: 'MEMBER', blocked: false }), { status: 200 }))
    await updateAdminAccount('account-1', 'MEMBER', false, request)
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/admin\/accounts\/account-1$/), expect.objectContaining({ method: 'PATCH', credentials: 'same-origin', body: JSON.stringify({ role: 'MEMBER', blocked: false }) }))
  })

  it('creates a one-time reset link for the selected account only', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ url: 'https://example.invalid/reset#token=opaque', expires_at: '2026-09-24T00:00:00Z' }), { status: 201 }))
    await expect(createPasswordResetLink('account-1', request)).resolves.toHaveProperty('expires_at')
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/admin\/password-reset-links$/), expect.objectContaining({ method: 'POST', credentials: 'same-origin', body: JSON.stringify({ account_id: 'account-1' }) }))
  })

  it('revokes only the explicitly selected voice participant', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ revoked_leases: 1 }), { status: 200 }))
    await expect(kickVoiceParticipant('account-2', request)).resolves.toEqual({ revoked_leases: 1 })
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/admin\/accounts\/account-2\/voice-kick$/), expect.objectContaining({ method: 'POST', credentials: 'same-origin' }))
  })
})
