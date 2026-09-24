<script setup lang="ts">
import { ref, watch } from 'vue'
import { changeOwnPassword, deleteAvatar, loadOwnProfile, saveOwnProfile, uploadAvatar, type OwnProfile } from './profile_client'

const props = defineProps<{ profile: OwnProfile | null; loading: boolean; loadError: string | null; logoutBusy?: boolean; logoutError?: string | null }>()
const emit = defineEmits<{ saved: [profile: OwnProfile]; logout: [] }>()
const displayName = ref(''); const currentPassword = ref(''); const newPassword = ref('')
const busy = ref(false); const error = ref<string | null>(null); const status = ref<string | null>(null)
watch(() => props.profile, (profile) => { displayName.value = profile?.display_name ?? '' }, { immediate: true })
function fail(cause: unknown, fallback: string): void { error.value = cause instanceof Error ? cause.message : fallback; status.value = null }
async function saveName(): Promise<void> {
  error.value = null; status.value = null
  if (Array.from(displayName.value).length < 1 || Array.from(displayName.value).length > 64) { error.value = 'Имя должно содержать от 1 до 64 символов.'; return }
  busy.value = true
  try { const profile = await saveOwnProfile(displayName.value); emit('saved', profile); status.value = 'Имя профиля сохранено.' } catch (cause) { fail(cause, 'Не удалось сохранить профиль.') } finally { busy.value = false }
}
async function selectAvatar(event: Event): Promise<void> {
  const input = event.target as HTMLInputElement; const file = input.files?.[0]; if (!file) return
  error.value = null; status.value = null; busy.value = true
  try { await uploadAvatar(file); emit('saved', await loadOwnProfile()); status.value = 'Аватар обновлён.' } catch (cause) { fail(cause, 'Не удалось загрузить аватар.') } finally { busy.value = false; input.value = '' }
}
async function removeAvatar(): Promise<void> {
  error.value = null; status.value = null; busy.value = true
  try { await deleteAvatar(); emit('saved', await loadOwnProfile()); status.value = 'Аватар удалён.' } catch (cause) { fail(cause, 'Не удалось удалить аватар.') } finally { busy.value = false }
}
async function changePassword(): Promise<void> {
  error.value = null; status.value = null
  if (Array.from(newPassword.value).length < 12 || Array.from(newPassword.value).length > 128) { error.value = 'Новый пароль должен содержать от 12 до 128 символов.'; return }
  busy.value = true
  try { await changeOwnPassword(currentPassword.value, newPassword.value); currentPassword.value = ''; newPassword.value = ''; status.value = 'Пароль изменён. Другие сессии завершены.' } catch (cause) { fail(cause, 'Не удалось изменить пароль.') } finally { busy.value = false }
}
</script>

<template>
  <section class="profile-settings" aria-labelledby="profile-settings-title" data-testid="profile-settings">
    <header><h1 id="profile-settings-title">Профиль</h1><p>Настройки вашей учётной записи</p></header>
    <p v-if="props.loading" class="state" aria-live="polite">Загружаем профиль…</p>
    <p v-else-if="props.loadError" class="state state-error" role="alert">{{ props.loadError }}</p>
    <template v-else-if="props.profile">
      <div class="profile-avatar-row">
        <img v-if="props.profile.avatar_url" class="profile-avatar" :src="props.profile.avatar_url" alt="Аватар профиля">
        <span v-else class="profile-avatar profile-avatar--empty" aria-hidden="true">{{ props.profile.display_name.slice(0, 1).toLocaleUpperCase('ru-RU') }}</span>
        <label class="profile-upload-button">Загрузить аватар<input type="file" accept="image/png,image/jpeg" :disabled="busy" @change="selectAvatar"></label>
        <button v-if="props.profile.avatar_url" class="profile-secondary-button" type="button" :disabled="busy" @click="removeAvatar">Удалить</button>
      </div>
      <form class="profile-form" @submit.prevent="saveName">
        <label>Имя пользователя<input v-model="displayName" autocomplete="nickname" maxlength="64" required></label>
        <label>Логин<input :value="props.profile.login" readonly aria-readonly="true"></label>
        <button type="submit" :disabled="busy">Сохранить изменения</button>
      </form>
      <form class="profile-form profile-password-form" @submit.prevent="changePassword">
        <h2>Изменить пароль</h2>
        <label>Текущий пароль<input v-model="currentPassword" type="password" autocomplete="current-password" minlength="12" maxlength="128" required></label>
        <label>Новый пароль<input v-model="newPassword" type="password" autocomplete="new-password" minlength="12" maxlength="128" required></label>
        <button type="submit" :disabled="busy">Обновить пароль</button>
      </form>
    </template>
    <p v-if="status" class="profile-status" aria-live="polite">{{ status }}</p>
    <p v-if="error" class="profile-error" role="alert">{{ error }}</p>
    <section class="profile-logout" aria-labelledby="profile-logout-title">
      <h2 id="profile-logout-title">Выход из аккаунта</h2>
      <p>Голосовое подключение завершится, а личные данные исчезнут с этого экрана.</p>
      <button class="profile-secondary-button" type="button" :disabled="busy || props.logoutBusy" @click="emit('logout')">{{ props.logoutBusy ? 'Выходим…' : 'Выйти из аккаунта' }}</button>
      <p v-if="props.logoutError" class="profile-error" role="alert">{{ props.logoutError }}</p>
    </section>
  </section>
</template>
