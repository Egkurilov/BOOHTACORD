import { describe, expect, it, vi } from 'vitest'

import { PasswordResetInvalidError } from './password_reset_client'
import { createPasswordResetForm } from './password_reset_form'

describe('password reset form', () => {
  it('submits a confirmed password once, clears fields, then offers ordinary login', async () => {
    const finish = vi.fn().mockResolvedValue(undefined)
    const form = createPasswordResetForm(finish)
    form.password.value = 'correct horse battery staple'
    form.confirmation.value = form.password.value

    await form.submit()
    expect(finish).toHaveBeenCalledExactlyOnceWith('correct horse battery staple')
    expect(form.completed.value).toBe(true)
    expect(form.password.value).toBe('')
    expect(form.confirmation.value).toBe('')
    await form.submit()
    expect(finish).toHaveBeenCalledOnce()
  })

  it('validates length by Unicode code points and matching confirmation', async () => {
    const finish = vi.fn()
    const form = createPasswordResetForm(finish)
    form.password.value = 'short'
    form.confirmation.value = 'short'
    await form.submit()
    expect(form.error.value).toContain('12')
    form.password.value = 'correct horse battery staple'
    form.confirmation.value = 'different password'
    await form.submit()
    expect(form.error.value).toContain('не совпадают')
    expect(finish).not.toHaveBeenCalled()
  })

  it('shows the same unusable-link state for invalid, expired and reused tokens', async () => {
    const finish = vi.fn().mockRejectedValue(new PasswordResetInvalidError())
    const invalid = vi.fn()
    const form = createPasswordResetForm(finish, invalid)
    form.password.value = 'correct horse battery staple'
    form.confirmation.value = form.password.value

    await form.submit()
    expect(form.unusable.value).toBe(true)
    expect(form.error.value).toContain('Ссылка недействительна')
    expect(invalid).toHaveBeenCalledOnce()
    expect(form.password.value).toBe('')
  })

  it('keeps the form retryable after a network failure', async () => {
    const finish = vi.fn().mockRejectedValueOnce(new Error('Нет связи с сервером')).mockResolvedValueOnce(undefined)
    const form = createPasswordResetForm(finish)
    form.password.value = 'correct horse battery staple'
    form.confirmation.value = form.password.value

    await form.submit()
    expect(form.completed.value).toBe(false)
    expect(form.error.value).toContain('Нет связи')
    await form.submit()
    expect(form.completed.value).toBe(true)
  })
})
