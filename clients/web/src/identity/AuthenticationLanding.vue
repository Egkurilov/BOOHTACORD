<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import { login, register } from './auth_client'
import { generateSecurePassword } from './password_generator'
import PasswordGenerationActions from './password_generation/PasswordGenerationActions.vue'

const props = withDefaults(defineProps<{ focusLoginOnMount?: boolean }>(), { focusLoginOnMount: false })
const emit = defineEmits<{ authenticated: [] }>()
const mode = ref<'login' | 'register'>('login')
const loginValue = ref('')
const loginInput = ref<HTMLInputElement | null>(null)
const password = ref('')
const pending = ref(false)
const error = ref<string | null>(null)
const showRecoveryHelp = ref(false)
const showPassword = ref(false)
const passwordInput = ref<HTMLInputElement | null>(null)
const passwordStatus = ref('')
const confirmGeneration = ref(false)
let active = true

onMounted(() => { if (props.focusLoginOnMount) loginInput.value?.focus() })

function chooseMode(nextMode: 'login' | 'register'): void {
  if (pending.value || mode.value === nextMode) return
  mode.value = nextMode
  error.value = null
  clearPassword()
}

function clearPassword(): void {
  password.value = ''
  if (passwordInput.value) passwordInput.value.value = ''
  showPassword.value = false
  confirmGeneration.value = false
  passwordStatus.value = ''
}

function requestPasswordGeneration(): void {
  if (password.value) { confirmGeneration.value = true; return }
  generatePassword()
}

function generatePassword(): void {
  try { password.value = generateSecurePassword() }
  catch { error.value = 'Не удалось безопасно сгенерировать пароль. Попробуйте ещё раз или введите его вручную.'; return }
  showPassword.value = true
  confirmGeneration.value = false
  error.value = null
  passwordStatus.value = 'Надёжный пароль сгенерирован'
  void nextTick(() => passwordInput.value?.focus())
}

async function submit(): Promise<void> {
  if (pending.value) return
  pending.value = true
  error.value = null
  const input = { login: loginValue.value, password: password.value }
  try {
    if (mode.value === 'register') await register(input)
    if (!active) return
    await login(input)
    if (!active) return
    clearPassword()
    emit('authenticated')
  } catch (cause) {
    if (active) error.value = cause instanceof Error ? cause.message.split(input.password).join('[скрыто]') : 'Не удалось выполнить вход.'
  } finally {
    input.password = ''
    if (active) pending.value = false
  }
}

onBeforeUnmount(() => { active = false; clearPassword() })
</script>

<template>
  <main class="authentication-page" aria-labelledby="authentication-title">
    <section class="authentication-card">
      <div class="authentication-brand"><img src="/brand.png" alt=""><p class="eyebrow">BOOHTACORD</p></div>
      <h1 id="authentication-title">Добро пожаловать</h1>
      <p class="authentication-intro">Войдите в «Моя гильдия».</p>

      <form class="authentication-form" @submit.prevent="submit">
        <label class="authentication-field">
          Логин
          <input v-model="loginValue" ref="loginInput" autocomplete="username" maxlength="32" minlength="3" pattern="[A-Za-z0-9_.-]{3,32}" required :aria-describedby="error ? 'authentication-error' : undefined" :aria-invalid="Boolean(error)">
        </label>
        <div class="authentication-field">
          <label for="authentication-password">Пароль</label>
          <span class="authentication-password-control"><input id="authentication-password" ref="passwordInput" v-model="password" @input="passwordStatus = ''; confirmGeneration = false" :autocomplete="mode === 'login' ? 'current-password' : 'new-password'" required :type="showPassword ? 'text' : 'password'" :aria-describedby="error ? 'authentication-error' : undefined" :aria-invalid="Boolean(error)"><button class="authentication-password-toggle" type="button" :disabled="pending" :aria-label="showPassword ? 'Скрыть пароль' : 'Показать пароль'" :aria-pressed="showPassword" @click="showPassword = !showPassword"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Zm10-3a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z" /></svg></button></span>
          <PasswordGenerationActions v-if="mode === 'register'" :pending="pending" :confirm="confirmGeneration" @generate="requestPasswordGeneration" @replace="generatePassword" @keep="confirmGeneration = false" />
        </div>
        <p v-if="mode === 'register'" class="authentication-hint">Логин: 3–32 символа A–Z, 0–9, `_`, `.`, `-`. Пароль — от 12 символов.</p>
        <p class="authentication-password-status" role="status" aria-live="polite" aria-atomic="true">{{ passwordStatus }}</p>
        <p v-if="error" id="authentication-error" class="authentication-error" role="alert">{{ error }}</p>
        <button class="authentication-submit" :disabled="pending" type="submit">
          {{ pending ? 'Подождите…' : mode === 'login' ? 'Войти' : 'Создать аккаунт' }}
        </button>
      </form>
      <aside class="authentication-account-help" aria-label="Восстановление доступа и регистрация">
        <p class="authentication-recovery-title">Не получается войти?</p>
        <button class="authentication-recovery-toggle" type="button" :aria-expanded="showRecoveryHelp" @click="showRecoveryHelp = !showRecoveryHelp">Как восстановить доступ</button>
        <p v-if="showRecoveryHelp" class="authentication-recovery-details">Попросите администратора гильдии выдать ссылку восстановления.</p>
        <div class="authentication-registration-footer"><p class="authentication-registration-note">Регистрация открыта.</p><button class="authentication-mode-toggle" type="button" :disabled="pending" @click="chooseMode(mode === 'login' ? 'register' : 'login')">{{ mode === 'login' ? 'Создать аккаунт' : 'Уже есть аккаунт? Войти' }}</button></div>
      </aside>
    </section>
  </main>
</template>
