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

  it('matches the mobile handoff type scale without changing registration behavior', () => {
    const css = readFileSync(new URL('./design_v2_authentication_presentation.css', import.meta.url), 'utf8')
    expect(css).toContain('.authentication-card h1 { margin: 32px 0 0; text-align: center; font-size: 24px; line-height: 32px; font-weight: 600; }')
    expect(css).toContain('.authentication-submit { height: 44px; min-height: 44px; margin-top: 0; font-weight: 500; }')
    expect(css).toContain('.authentication-brand .eyebrow { font-size: 16px; }')
  })
})
