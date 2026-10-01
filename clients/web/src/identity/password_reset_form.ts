import { ref } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'

import { PasswordResetInvalidError } from './password_reset_client'

export function createPasswordResetForm(finish: (password: string) => Promise<void>, onInvalid: () => void = () => {}) {
  const password = ref('')
  const confirmation = ref('')
  const pending = ref(false)
  const completed = ref(false)
  const unusable = ref(false)
  const error = ref<string | null>(null)

  async function submit(): Promise<void> {
    if (pending.value || completed.value || unusable.value) return
    error.value = null
    if (!validCodePointLength(password.value, 12, 128)) {
      error.value = 'Пароль должен содержать от 12 до 128 символов.'
      return
    }
    if (password.value !== confirmation.value) {
      error.value = 'Пароли не совпадают.'
      return
    }
    pending.value = true
    try {
      await finish(password.value)
      completed.value = true
    } catch (cause) {
      if (cause instanceof PasswordResetInvalidError) {
        unusable.value = true
        onInvalid()
      }
      error.value = cause instanceof Error ? cause.message : 'Не удалось изменить пароль. Повторите попытку.'
    } finally {
      pending.value = false
      if (completed.value || unusable.value) {
        password.value = ''
        confirmation.value = ''
      }
    }
  }

  return { password, confirmation, pending, completed, unusable, error, submit }
}
