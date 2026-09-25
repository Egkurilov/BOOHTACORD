<script setup lang="ts">
import { onMounted, ref } from 'vue'

import { login, register } from './auth_client'

const props = withDefaults(defineProps<{ focusLoginOnMount?: boolean }>(), { focusLoginOnMount: false })
const emit = defineEmits<{ authenticated: [] }>()
const mode = ref<'login' | 'register'>('login')
const loginValue = ref('')
const loginInput = ref<HTMLInputElement | null>(null)
const password = ref('')
const pending = ref(false)
const error = ref<string | null>(null)

onMounted(() => { if (props.focusLoginOnMount) loginInput.value?.focus() })

function chooseMode(nextMode: 'login' | 'register'): void {
  mode.value = nextMode
  error.value = null
}

async function submit(): Promise<void> {
  pending.value = true
  error.value = null
  const input = { login: loginValue.value, password: password.value }
  try {
    if (mode.value === 'register') await register(input)
    await login(input)
    password.value = ''
    emit('authenticated')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'Не удалось выполнить вход.'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <main class="authentication-page" aria-labelledby="authentication-title">
    <section class="authentication-card">
      <p class="eyebrow">На своём сервере · одна гильдия</p>
      <h1 id="authentication-title">Voice Platform</h1>
      <p class="authentication-intro">Голосовые каналы, демонстрация экрана и общий чат для своей компании.</p>

      <div class="authentication-tabs" role="tablist" aria-label="Действие с аккаунтом">
        <button :aria-selected="mode === 'login'" :class="{ selected: mode === 'login' }" role="tab" type="button" @click="chooseMode('login')">Войти</button>
        <button :aria-selected="mode === 'register'" :class="{ selected: mode === 'register' }" role="tab" type="button" @click="chooseMode('register')">Регистрация</button>
      </div>

      <form class="authentication-form" @submit.prevent="submit">
        <label class="authentication-field">
          Логин
          <input v-model="loginValue" ref="loginInput" autocomplete="username" maxlength="32" minlength="3" pattern="[A-Za-z0-9_.-]{3,32}" required :aria-describedby="error ? 'authentication-error' : undefined" :aria-invalid="Boolean(error)">
        </label>
        <label class="authentication-field">
          Пароль
          <input v-model="password" :autocomplete="mode === 'login' ? 'current-password' : 'new-password'" required type="password" :aria-describedby="error ? 'authentication-error' : undefined" :aria-invalid="Boolean(error)">
        </label>
        <p v-if="mode === 'register'" class="authentication-hint">Логин: 3–32 символа A–Z, 0–9, `_`, `.`, `-`. Пароль — от 12 символов.</p>
        <p v-if="error" id="authentication-error" class="authentication-error" role="alert">{{ error }}</p>
        <button class="authentication-submit" :disabled="pending" type="submit">
          {{ pending ? 'Подождите…' : mode === 'login' ? 'Войти' : 'Создать аккаунт' }}
        </button>
      </form>
    </section>
  </main>
</template>
