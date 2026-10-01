import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const app = readFileSync(new URL('../App.vue', import.meta.url), 'utf8')
const screen = readFileSync(new URL('./PasswordResetCompletion.vue', import.meta.url), 'utf8')

describe('password reset App wiring', () => {
  it('consumes the fragment before session bootstrap and skips bootstrap on the reset route', () => {
    const intake = app.indexOf('consumePasswordResetFragment(window.location, window.history)')
    const sessionRequest = app.indexOf('await loadCurrentSession()')
    expect(intake).toBeGreaterThan(0)
    expect(intake).toBeLessThan(sessionRequest)
    expect(app).toContain('if (!resetRoute.value) void refreshSession()')
    expect(app).toContain('<PasswordResetCompletion v-if="resetRoute"')
  })

  it('keeps the secret out of child props and restores the ordinary login screen', () => {
    expect(app).toContain('let resetToken: string | null = null')
    expect(app).toContain(':complete="finishPasswordReset"')
    expect(app).not.toContain(':token="resetToken"')
    expect(app).toContain("state.value = 'guest'")
    expect(app).toContain("window.history.replaceState(window.history.state, '', '/')")
    expect(screen).toContain("emit('returnToLogin')")
    for (const source of [app, screen]) {
      expect(source).not.toContain('localStorage')
      expect(source).not.toContain('sessionStorage')
      expect(source).not.toContain('console.')
    }
  })
})
