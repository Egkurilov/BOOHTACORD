<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import { login, register } from './auth_client'
import { generateSecurePassword } from './password_generator'

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

onMounted(() => { if (props.focusLoginOnMount) loginInput.value?.focus() })

function chooseMode(nextMode: 'login' | 'register'): void {
  mode.value = nextMode
  error.value = null
  password.value = ''
  showPassword.value = false
  confirmGeneration.value = false
  passwordStatus.value = ''
}

function requestPasswordGeneration(): void {
  if (password.value) { confirmGeneration.value = true; return }
  generatePassword()
}

function generatePassword(): void {
  password.value = generateSecurePassword()
  showPassword.value = true
  confirmGeneration.value = false
  error.value = null
  passwordStatus.value = 'Надёжный пароль сгенерирован'
  void nextTick(() => passwordInput.value?.focus())
}

async function submit(): Promise<void> {
  pending.value = true
  error.value = null
  const input = { login: loginValue.value, password: password.value }
  try {
    if (mode.value === 'register') await register(input)
    await login(input)
    password.value = ''
    showPassword.value = false
    passwordStatus.value = ''
    emit('authenticated')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'Не удалось выполнить вход.'
  } finally {
    pending.value = false
  }
}

onBeforeUnmount(() => { password.value = '' })
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
        <label class="authentication-field">
          Пароль
          <span class="authentication-password-control"><input ref="passwordInput" v-model="password" :autocomplete="mode === 'login' ? 'current-password' : 'new-password'" required :type="showPassword ? 'text' : 'password'" :aria-describedby="error ? 'authentication-error' : undefined" :aria-invalid="Boolean(error)"><button class="authentication-password-toggle" type="button" :aria-label="showPassword ? 'Скрыть пароль' : 'Показать пароль'" :aria-pressed="showPassword" @click="showPassword = !showPassword"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Zm10-3a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z" /></svg></button></span>
          <div v-if="mode === 'register'" class="authentication-password-generation">
            <button class="authentication-password-generate" type="button" :disabled="pending" @click="requestPasswordGeneration">Сгенерировать пароль</button>
            <p v-if="confirmGeneration" class="authentication-password-confirm" role="alert">Заменить введённый пароль сгенерированным?</p>
            <span v-if="confirmGeneration" class="authentication-password-confirm-actions"><button type="button" @click="generatePassword">Заменить</button><button type="button" @click="confirmGeneration = false">Оставить</button></span>
          </div>
        </label>
        <p v-if="mode === 'register'" class="authentication-hint">Логин: 3–32 символа A–Z, 0–9, `_`, `.`, `-`. Пароль — от 12 символов.</p>
        <p v-if="passwordStatus" class="authentication-password-status" role="status" aria-live="polite">{{ passwordStatus }}</p>
        <p v-if="error" id="authentication-error" class="authentication-error" role="alert">{{ error }}</p>
        <button class="authentication-submit" :disabled="pending" type="submit">
          {{ pending ? 'Подождите…' : mode === 'login' ? 'Войти' : 'Создать аккаунт' }}
        </button>
      </form>
      <aside class="authentication-account-help" aria-label="Восстановление доступа и регистрация">
        <p class="authentication-recovery-title">Не получается войти?</p>
        <button class="authentication-recovery-toggle" type="button" :aria-expanded="showRecoveryHelp" @click="showRecoveryHelp = !showRecoveryHelp">Как восстановить доступ</button>
        <p v-if="showRecoveryHelp" class="authentication-recovery-details">Попросите администратора гильдии выдать ссылку восстановления.</p>
        <div class="authentication-registration-footer"><p class="authentication-registration-note">Регистрация открыта.</p><button class="authentication-mode-toggle" type="button" @click="chooseMode(mode === 'login' ? 'register' : 'login')">{{ mode === 'login' ? 'Создать аккаунт' : 'Уже есть аккаунт? Войти' }}</button></div>
      </aside>
    </section>
  </main>
</template>
