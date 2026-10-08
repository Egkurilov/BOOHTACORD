import { describe, expect, it, vi } from 'vitest'
import { createVoiceTimeoutState } from './state'
import type { VoiceTimeoutState } from './client'

const inactive: VoiceTimeoutState = { active: false, revoked_leases: 0, revocation_pending: false }
describe('voice timeout request lifecycle', () => {
  it('requires successful explicit load before any mutation', async () => {
    const gateway = vi.fn().mockResolvedValue(inactive)
    const state = createVoiceTimeoutState('selected', gateway, () => 0)
    await state.set(5, 'SPAM'); expect(gateway).not.toHaveBeenCalled()
    await state.load(); await state.set(15, 'SPAM')
    expect(gateway).toHaveBeenLastCalledWith('selected', 'PUT',
      { expires_at: '1970-01-01T00:15:00.000Z', reason_code: 'SPAM' }, expect.any(AbortSignal))
  })
  it('retains pending removal on clear without invoking any media action', async () => {
    const gateway = vi.fn().mockResolvedValueOnce({ ...inactive, active: true })
      .mockResolvedValueOnce({ ...inactive, revocation_pending: true })
    const state = createVoiceTimeoutState('selected', gateway)
    await state.load(); await state.clear()
    expect(state.value.value).toEqual({ ...inactive, revocation_pending: true })
    expect(gateway.mock.calls.map(call => call[1])).toEqual(['GET', 'DELETE'])
  })
  it('ignores disposed results and aborts network work', async () => {
    let resolve!: (value: VoiceTimeoutState) => void
    const gateway = vi.fn().mockImplementation(() => new Promise<VoiceTimeoutState>(done => { resolve = done }))
    const state = createVoiceTimeoutState('selected', gateway)
    const loading = state.load(); const signal = gateway.mock.calls[0][3] as AbortSignal
    state.dispose(); resolve(inactive); await loading
    expect(signal.aborted).toBe(true); expect(state.value.value).toBeNull()
  })
  it('rejects invalid duration and clears stale success on request failure', async () => {
    const gateway = vi.fn().mockResolvedValueOnce(inactive).mockRejectedValue(new Error('private details'))
    const state = createVoiceTimeoutState('selected', gateway)
    await state.load(); await state.set(0, 'SPAM'); expect(gateway).toHaveBeenCalledOnce()
    await state.clear(); expect(state.value.value).toBeNull()
    expect(state.error.value).not.toContain('private details')
  })
})
