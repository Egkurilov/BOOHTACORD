import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const screen = readFileSync(new URL('./PasswordResetCompletion.vue', import.meta.url), 'utf8')

describe('password reset field descriptions', () => {
  it('exposes the password length hint with and without a validation error', () => {
    const passwordInput = screen.match(/<input[^>]+v-model="password"[^>]*>/)?.[0]
    expect(passwordInput).toBeDefined()
    expect(screen).toMatch(/<p[^>]+id="password-reset-length-hint"[^>]*>От 12 до 128 символов\.<\/p>/)
    expect(passwordInput).toContain("error ? 'password-reset-length-hint password-reset-error' : 'password-reset-length-hint'")
  })
})
