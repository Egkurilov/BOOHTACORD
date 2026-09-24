<script setup lang="ts">
import { createPasswordResetForm } from './password_reset_form'

const props = defineProps<{ validLink: boolean; complete: (password: string) => Promise<void> }>()
const emit = defineEmits<{ invalidLink: []; returnToLogin: [] }>()
const { password, confirmation, pending, completed, unusable, error, submit } = createPasswordResetForm(
  (value) => props.complete(value),
  () => emit('invalidLink'),
)
</script>

<template>
  <main class="authentication-page" aria-labelledby="password-reset-title">
    <section class="authentication-card">
      <p class="eyebrow">Безопасность аккаунта</p>
      <h1 id="password-reset-title">Новый пароль</h1>
      <p v-if="completed" class="authentication-intro" role="status">Пароль изменён. Войдите в аккаунт с новым паролем.</p>
      <p v-else-if="!validLink || unusable" class="authentication-error" role="alert">{{ error ?? 'Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.' }}</p>
      <form v-else class="authentication-form" @submit.prevent="submit">
        <label class="authentication-field">Новый пароль
          <input v-model="password" type="password" autocomplete="new-password" required :disabled="pending" :aria-invalid="Boolean(error)" :aria-describedby="error ? 'password-reset-error' : undefined">
        </label>
        <label class="authentication-field">Повторите пароль
          <input v-model="confirmation" type="password" autocomplete="new-password" required :disabled="pending" :aria-invalid="Boolean(error)" :aria-describedby="error ? 'password-reset-error' : undefined">
        </label>
        <p class="authentication-hint">От 12 до 128 символов.</p>
        <p v-if="error" id="password-reset-error" class="authentication-error" role="alert">{{ error }}</p>
        <button class="authentication-submit" type="submit" :disabled="pending">{{ pending ? 'Меняем пароль…' : 'Изменить пароль' }}</button>
      </form>
      <button v-if="completed || !validLink || unusable" class="authentication-submit" type="button" @click="emit('returnToLogin')">Перейти ко входу</button>
    </section>
  </main>
</template>
