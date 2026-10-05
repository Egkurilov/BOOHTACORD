import { describe, expect, it, vi } from 'vitest'
import { createAuthenticationFlow } from './flow'

describe('registration followed by real login', () => {
  it('confirms registration, preserves password bytes and retries only login', async () => {
    const password = '  пароль😀e\u0301длинный  '
    const register = vi.fn(async (input) => { expect(input.password).toBe(password) })
    const login = vi.fn().mockRejectedValueOnce(new Error('network')).mockImplementation(async (input) => {
      expect(input.password).toBe(password)
    })
    const flow = createAuthenticationFlow({ register, login })
    expect(await flow.submit('register', { login: 'member', password })).toBe(false)
    expect(flow.registered.value).toBe(true)
    expect(flow.notice.value).toContain('Аккаунт создан')
    expect(flow.notice.value).toContain('Войти')
    expect(await flow.submit('register', { login: 'member', password })).toBe(true)
    expect(register).toHaveBeenCalledOnce()
    expect(login).toHaveBeenCalledTimes(2)
  })

  it('never starts an automatic retry after 429', async () => {
    const login = vi.fn().mockRejectedValue(new Error('Повторите вручную через 42 с.'))
    const flow = createAuthenticationFlow({ register: vi.fn(), login })
    await flow.submit('login', { login: 'member', password: 'private password' })
    await new Promise(resolve => setTimeout(resolve, 5))
    expect(login).toHaveBeenCalledOnce()
    expect(flow.error.value).toContain('42 с.')
    expect(flow.pending.value).toBe(false)
  })

  it('changing login creates the new account and hides passwords in errors', async () => {
    const register = vi.fn(async () => {})
    const login = vi.fn().mockRejectedValue(new Error('secret password'))
    const flow = createAuthenticationFlow({ register, login })
    await flow.submit('register', { login: 'first', password: 'secret password' })
    expect(flow.error.value).not.toContain('secret password')
    await flow.submit('register', { login: 'second', password: 'secret password' })
    expect(register).toHaveBeenCalledTimes(2)
  })

  it('disposal during registration prevents login and stale notice updates', async () => {
    let done!: () => void
    const register = vi.fn(() => new Promise<void>(resolve => { done = resolve }))
    const login = vi.fn()
    const flow = createAuthenticationFlow({ register, login })
    const pending = flow.submit('register', { login: 'first', password: 'secret password' })
    flow.dispose()
    done()
    expect(await pending).toBe(false)
    expect(login).not.toHaveBeenCalled()
  })
})
