import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { copyAdminResetLink } from './admin_reset_link_copy'

describe('administrator reset-link copy feedback', () => {
  it('replaces a prior success with only the current clipboard failure', async () => {
    const status = ref<string | null>('Одноразовая ссылка скопирована.')
    const error = ref<string | null>(null)
    const write = vi.fn().mockRejectedValue(new Error('clipboard unavailable'))

    await copyAdminResetLink('https://example.invalid/reset#synthetic', write, status, error)

    expect(status.value).toBeNull()
    expect(error.value).toBe('Не удалось скопировать ссылку. Скопируйте её из поля вручную.')
  })

  it('clears a prior clipboard error after a successful retry', async () => {
    const status = ref<string | null>(null)
    const error = ref<string | null>('Не удалось скопировать ссылку.')
    const write = vi.fn().mockResolvedValue(undefined)

    await copyAdminResetLink('https://example.invalid/reset#synthetic', write, status, error)

    expect(write).toHaveBeenCalledOnce()
    expect(error.value).toBeNull()
    expect(status.value).toBe('Одноразовая ссылка скопирована.')
  })
})
