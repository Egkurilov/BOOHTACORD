import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const screen = readFileSync(new URL('./AuthenticationLanding.vue', import.meta.url), 'utf8')

describe('registration password generator UI contract', () => {
  it('keeps generation registration-only and announces without exposing the secret', () => {
    expect(screen).toContain('v-if="mode === \'register\'" class="authentication-password-generation"')
    expect(screen).toContain('Сгенерировать пароль')
    expect(screen).toContain('Надёжный пароль сгенерирован')
    expect(screen).not.toContain('console.log(password')
    expect(screen).not.toContain('navigator.clipboard')
  })

  it('requires confirmation before replacing entered text and clears on mode changes', () => {
    expect(screen).toContain('Заменить введённый пароль сгенерированным?')
    expect(screen).toContain("password.value = ''")
    expect(screen).toContain('showPassword.value = false')
  })
})

