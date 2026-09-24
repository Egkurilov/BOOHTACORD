import { describe, expect, it, vi } from 'vitest'

import { consumePasswordResetFragment } from './password_reset_fragment'

describe('password reset link intake', () => {
  it('extracts the opaque fragment and erases it synchronously before any request', () => {
    const history = { state: { route: 'reset' }, replaceState: vi.fn() }
    const result = consumePasswordResetFragment({ pathname: '/reset-password', search: '', hash: '#token=opaque%2Bsecret' }, history)

    expect(result).toEqual({ resetRoute: true, token: 'opaque+secret' })
    expect(history.replaceState).toHaveBeenCalledOnce()
    expect(history.replaceState).toHaveBeenCalledWith(history.state, '', '/reset-password')
    expect(JSON.stringify(history.replaceState.mock.calls)).not.toContain('opaque')
  })

  it('erases malformed reset fragments and exposes no usable token', () => {
    const history = { state: null, replaceState: vi.fn() }
    const result = consumePasswordResetFragment({ pathname: '/reset-password', search: '', hash: '#token=' }, history)

    expect(result).toEqual({ resetRoute: true, token: null })
    expect(history.replaceState).toHaveBeenCalledWith(null, '', '/reset-password')
  })

  it('removes a legacy query string together with the fragment instead of retaining a secret URL', () => {
    const history = { state: null, replaceState: vi.fn() }
    const result = consumePasswordResetFragment({ pathname: '/reset-password', search: '?token=legacy', hash: '#token=opaque' }, history)

    expect(result.token).toBe('opaque')
    expect(history.replaceState).toHaveBeenCalledWith(null, '', '/reset-password')
  })

  it('does not consume fragments from unrelated routes', () => {
    const history = { state: null, replaceState: vi.fn() }
    const result = consumePasswordResetFragment({ pathname: '/', search: '', hash: '#navigation' }, history)

    expect(result).toEqual({ resetRoute: false, token: null })
    expect(history.replaceState).not.toHaveBeenCalled()
  })
})
