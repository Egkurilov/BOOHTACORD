import { ref } from 'vue'
import { login, register, type AuthenticationInput } from '../auth_client'

export function createAuthenticationFlow(transport = { login, register }) {
  const pending = ref(false), error = ref<string | null>(null), notice = ref(''), registered = ref(false)
  let active = true, registeredLogin: string | null = null

  function reset(): void {
    if (pending.value) return
    registeredLogin = null
    registered.value = false
    error.value = null
    notice.value = ''
  }

  async function submit(mode: 'login' | 'register', source: AuthenticationInput): Promise<boolean> {
    if (!active || pending.value) return false
    const input = { ...source }
    if (registeredLogin !== input.login) reset()
    pending.value = true
    error.value = null
    try {
      if (mode === 'register' && !registered.value) {
        await transport.register(input)
        if (!active) return false
        registeredLogin = input.login
        registered.value = true
        notice.value = 'Аккаунт создан. Выполняем автоматический вход…'
      }
      await transport.login(input)
      if (!active) return false
      notice.value = registered.value ? 'Аккаунт создан. Вы вошли автоматически.' : 'Вход выполнен.'
      return true
    } catch (cause) {
      if (active) {
        const message = cause instanceof Error ? cause.message : 'Не удалось выполнить вход.'
        error.value = input.password ? message.split(input.password).join('[скрыто]') : message
        if (registered.value) notice.value = 'Аккаунт создан. Автоматический вход не выполнен. Нажмите «Войти», чтобы повторить только вход.'
      }
      return false
    } finally { input.password = ''; if (active) pending.value = false }
  }

  return { pending, error, notice, registered, submit, reset, dispose: () => { active = false } }
}
