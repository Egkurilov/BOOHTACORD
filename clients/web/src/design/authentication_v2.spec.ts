import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import authentication from '../identity/AuthenticationLanding.vue?raw'

describe('V2 authentication presentation', () => {
  it('keeps the real login and registration actions with the branded login form', () => {
    expect(authentication).toContain('class="authentication-brand"')
    expect(authentication).toContain('class="authentication-password-toggle"')
    expect(authentication).toContain("if (mode.value === 'register') await register(input)")
    expect(authentication).toContain('await login(input)')
    expect(readFileSync(new URL('./design_v2_authentication_presentation.css', import.meta.url), 'utf8')).toContain('.authentication-card')
  })
})
