<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import { changeOwnPassword, deleteAvatar, loadOwnProfile, saveOwnProfile, uploadAvatar, type OwnProfile } from './profile_client'
import NotificationSettings from '../notification/NotificationSettings.vue'
import UpdateStatus from '../updates/UpdateStatus.vue'
import OwnSessionsPanel from './own_sessions/OwnSessionsPanel.vue'
type ProfileTab = 'profile' | 'security' | 'notifications' | 'about'

const props = defineProps<{ profile: OwnProfile | null; loading: boolean; loadError: string | null; logoutBusy?: boolean; logoutError?: string | null }>()
const emit = defineEmits<{ saved: [profile: OwnProfile]; logout: []; sessionExpired: [] }>()
const displayName = ref(''); const currentPassword = ref(''); const newPassword = ref('')
const busy = ref(false); const error = ref<string | null>(null); const status = ref<string | null>(null)
const activeTab = ref<ProfileTab>('profile')
const nameChanged = computed(() => displayName.value !== (props.profile?.display_name ?? ''))
const title = ref<HTMLElement | null>(null)
let focusFrame: number | null = null
onMounted(() => { focusFrame = window.requestAnimationFrame(() => title.value?.focus()) })
onBeforeUnmount(() => { if (focusFrame !== null) window.cancelAnimationFrame(focusFrame) })
watch(() => props.profile, (profile) => { displayName.value = profile?.display_name ?? '' }, { immediate: true })
function fail(cause: unknown, fallback: string): void { error.value = cause instanceof Error ? cause.message : fallback; status.value = null }
async function saveName(): Promise<void> {
  error.value = null; status.value = null
  if (!validCodePointLength(displayName.value, 1, 64)) { error.value = 'Имя должно содержать от 1 до 64 символов.'; return }
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
  if (!validCodePointLength(currentPassword.value, 12, 128) || !validCodePointLength(newPassword.value, 12, 128)) { error.value = 'Пароль должен содержать от 12 до 128 символов.'; return }
  busy.value = true
  try { await changeOwnPassword(currentPassword.value, newPassword.value); currentPassword.value = ''; newPassword.value = ''; status.value = 'Пароль изменён. Другие сессии завершены.' } catch (cause) { fail(cause, 'Не удалось изменить пароль.') } finally { busy.value = false }
}
</script>

<template>
  <section class="profile-settings" aria-labelledby="profile-settings-title" data-testid="profile-settings">
    <header><h1 id="profile-settings-title" ref="title" tabindex="-1">Настройки</h1><p>Ваш профиль и параметры приложения.</p></header>
    <nav class="profile-tabs" role="tablist" aria-label="Настройки аккаунта">
      <button type="button" role="tab" :aria-selected="activeTab === 'profile'" @click="activeTab = 'profile'">Профиль</button>
      <button type="button" role="tab" :aria-selected="activeTab === 'security'" @click="activeTab = 'security'">Безопасность</button>
      <button type="button" role="tab" :aria-selected="activeTab === 'notifications'" @click="activeTab = 'notifications'">Уведомления</button>
      <button type="button" role="tab" :aria-selected="activeTab === 'about'" @click="activeTab = 'about'">О приложении</button>
    </nav>
    <p v-if="props.loading" class="state" aria-live="polite">Загружаем профиль…</p>
    <p v-else-if="props.loadError" class="state state-error" role="alert">{{ props.loadError }}</p>
    <template v-else-if="props.profile && activeTab === 'profile'">
      <section class="profile-panel" role="tabpanel" aria-label="Профиль">
      <div class="profile-avatar-row">
        <img v-if="props.profile.avatar_url" class="profile-avatar" :src="props.profile.avatar_url" alt="Аватар профиля">
        <span v-else class="profile-avatar profile-avatar--empty" aria-hidden="true">{{ props.profile.display_name.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span>
        <div class="profile-avatar-copy"><h2>{{ props.profile.display_name }}</h2><p>@{{ props.profile.login }} · {{ props.profile.role === 'ADMINISTRATOR' ? 'Администратор' : 'Участник' }}</p><label class="profile-upload-button">Изменить аватар<input type="file" accept="image/png,image/jpeg" :disabled="busy" @change="selectAvatar"></label></div>
        <button v-if="props.profile.avatar_url" class="profile-secondary-button" type="button" :disabled="busy" @click="removeAvatar">Удалить</button>
      </div>
      <form class="profile-form" @submit.prevent="saveName">
        <label>Отображаемое имя<input v-model="displayName" autocomplete="nickname" required :aria-describedby="error ? 'profile-error' : undefined"><small>Так вас видят другие участники гильдии.</small></label>
        <label>Логин<input :value="props.profile.login" readonly aria-readonly="true"><small>Используется для входа.</small></label>
        <div class="profile-savebar"><span>{{ status || (nameChanged ? 'Есть несохранённые изменения' : 'Изменения не внесены') }}</span><button type="submit" :disabled="busy || !nameChanged">Сохранить профиль</button></div>
      </form>
      </section>
    </template>
    <template v-else-if="props.profile && activeTab === 'security'">
      <section class="profile-panel" role="tabpanel" aria-label="Безопасность">
      <form class="profile-form profile-password-form" @submit.prevent="changePassword">
        <h2>Изменить пароль</h2>
        <label>Текущий пароль<input v-model="currentPassword" type="password" autocomplete="current-password" required :aria-describedby="error ? 'profile-error' : undefined"></label>
        <label>Новый пароль<input v-model="newPassword" type="password" autocomplete="new-password" required :aria-describedby="error ? 'profile-error' : undefined"></label>
        <button type="submit" :disabled="busy">Обновить пароль</button>
      </form>
      <section class="profile-logout" aria-labelledby="profile-logout-title">
        <h2 id="profile-logout-title">Выход из аккаунта</h2>
        <p>Голосовое подключение завершится, а личные данные исчезнут с этого экрана.</p>
        <button class="profile-secondary-button" type="button" :disabled="busy || props.logoutBusy" @click="emit('logout')">{{ props.logoutBusy ? 'Выходим…' : 'Выйти из аккаунта' }}</button>
        <p v-if="props.logoutError" class="profile-error" role="alert">{{ props.logoutError }}</p>
      </section>
      <OwnSessionsPanel :account-id="props.profile.account_id" @session-expired="emit('sessionExpired')" />
      </section>
    </template>
    <template v-else-if="props.profile && activeTab === 'notifications'"><section class="profile-panel" role="tabpanel" aria-label="Уведомления"><NotificationSettings /></section></template>
    <template v-else-if="props.profile && activeTab === 'about'"><section class="profile-panel" role="tabpanel" aria-label="О приложении"><UpdateStatus /></section></template>
    <p v-if="status && activeTab !== 'profile'" class="profile-status" aria-live="polite">{{ status }}</p>
    <p v-if="error" id="profile-error" class="profile-error" role="alert">{{ error }}</p>
  </section>
</template>
