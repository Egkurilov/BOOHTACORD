<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { createPasswordResetLink, listAdminAccounts, updateAdminAccount, type AdminAccount, type PasswordResetLink } from '../../identity/admin_directory_client'
import { avatarBackground, avatarForeground } from '../../design/avatar_color'
import { avatarInitials } from '../../design/avatar_initials'
import { restoreAdminSaveFocus } from './admin_member_save_focus'
import { copyAdminResetLink } from './admin_reset_link_copy'

const accounts = ref<AdminAccount[]>([]); const cursor = ref<string | undefined>(); const loading = ref(false); const busyID = ref('')
const error = ref<string | null>(null); const status = ref<string | null>(null)
const resetLink = ref<(PasswordResetLink & { login: string }) | null>(null)
const resetTrigger = ref<HTMLButtonElement | null>(null)
const resetResult = ref<HTMLElement | null>(null)
const drafts = reactive<Record<string, { role: AdminAccount['role']; blocked: boolean }>>({})
const search = ref(''); const roleFilter = ref<'ALL' | AdminAccount['role']>('ALL'); const activeActionsID = ref('')
const filteredAccounts = computed(() => accounts.value.filter((account) => (roleFilter.value === 'ALL' || account.role === roleFilter.value) && `${account.display_name} ${account.login}`.toLocaleLowerCase().includes(search.value.trim().toLocaleLowerCase())))
async function load(next?: string): Promise<void> {
  loading.value = true; error.value = null
  try { const page = await listAdminAccounts(next); accounts.value = next ? [...accounts.value, ...page.accounts] : page.accounts; cursor.value = page.next_cursor; for (const account of page.accounts) drafts[account.account_id] = { role: account.role, blocked: account.blocked } }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить участников.' } finally { loading.value = false }
}
async function save(account: AdminAccount, event: MouseEvent): Promise<void> {
  const draft = drafts[account.account_id]; if (!draft) return
  const trigger = event.currentTarget as HTMLButtonElement
  const wasFocused = document.activeElement === trigger
  error.value = null; status.value = null; busyID.value = account.account_id
  try { await updateAdminAccount(account.account_id, draft.role, draft.blocked); status.value = `Права аккаунта ${account.login} сохранены.`; await load() }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось изменить аккаунт.' } finally { busyID.value = ''; await nextTick(); restoreAdminSaveFocus(trigger, wasFocused, document.activeElement, document.body) }
}
async function createReset(account: AdminAccount, event: MouseEvent): Promise<void> {
  resetTrigger.value = event.currentTarget as HTMLButtonElement
  resetLink.value = null; error.value = null; status.value = null; busyID.value = account.account_id
  try { resetLink.value = { ...await createPasswordResetLink(account.account_id), login: account.login }; await nextTick(); resetResult.value?.querySelector('input')?.focus() }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось создать ссылку восстановления.' } finally { busyID.value = '' }
}
function closeReset(): void { resetLink.value = null; void nextTick(() => resetTrigger.value?.isConnected && resetTrigger.value.focus()) }
async function copyResetLink(): Promise<void> {
  if (!resetLink.value) return
  await copyAdminResetLink(resetLink.value.url, (url) => navigator.clipboard.writeText(url), status, error)
}
onMounted(() => { void load() })
</script>

<template>
  <section class="admin-directory" aria-labelledby="admin-members-title">
    <header class="admin-section-heading"><div><h2 id="admin-members-title">Участники <span>{{ accounts.length }}</span></h2></div><button type="button" :disabled="loading" @click="load()">Обновить</button></header>
    <div class="admin-member-filters"><label><span class="gc-sr-only">Поиск участников</span><input v-model="search" type="search" placeholder="Поиск по имени или логину" autocomplete="off"></label><label><span class="gc-sr-only">Фильтр по роли</span><select v-model="roleFilter"><option value="ALL">Все роли</option><option value="MEMBER">Пользователь</option><option value="ADMINISTRATOR">Администратор</option></select></label></div>
    <p v-if="loading && !accounts.length" class="state" aria-live="polite">Загружаем список участников…</p>
    <p v-else-if="!loading && !accounts.length && !error" class="state">Участников пока нет.</p>
    <div v-if="accounts.length" class="admin-table-scroll" tabindex="0" aria-label="Таблица участников">
      <table class="admin-table"><thead><tr><th>Пользователь</th><th>Роль</th><th>Доступ</th><th></th></tr></thead><tbody>
        <tr v-for="account in filteredAccounts" :key="account.account_id">
          <td><span class="admin-account-user"><span class="admin-account-avatar" :style="{ backgroundColor: avatarBackground(account.account_id), color: avatarForeground(account.account_id) }">{{ avatarInitials(account.display_name) }}</span><span><strong>{{ account.display_name }}</strong><small>@{{ account.login }}</small></span></span></td>
          <td>{{ account.role === 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь' }}</td>
          <td><span class="admin-account-status" :class="account.blocked ? 'is-blocked' : 'is-active'">{{ account.blocked ? 'Заблокирован' : 'Активен' }}</span></td>
          <td class="admin-account-actions"><button type="button" :aria-label="`Действия с участником ${account.display_name}`" :aria-expanded="activeActionsID === account.account_id" @click="activeActionsID = activeActionsID === account.account_id ? '' : account.account_id">⋯</button><div v-if="activeActionsID === account.account_id" class="admin-account-actions-menu"><label>Роль<select v-model="drafts[account.account_id].role" :disabled="busyID === account.account_id" :aria-label="`Роль: ${account.login}`"><option value="MEMBER">Участник</option><option value="ADMINISTRATOR">Администратор</option></select></label><label class="admin-block-toggle"><input v-model="drafts[account.account_id].blocked" type="checkbox" :disabled="busyID === account.account_id" :aria-label="`Заблокирован: ${account.login}`"> Заблокирован</label><button type="button" :disabled="busyID === account.account_id" :aria-label="`Сохранить изменения для ${account.login}`" @click="save(account, $event)">Сохранить</button><button type="button" :disabled="busyID === account.account_id" :aria-label="`Сбросить пароль для ${account.login}`" @click="createReset(account, $event)">Сбросить пароль</button></div></td>
        </tr>
      </tbody></table>
    </div>
    <div v-if="accounts.length" class="admin-mobile-list" aria-label="Участники гильдии">
      <details v-for="account in filteredAccounts" :key="`mobile-${account.account_id}`" class="admin-mobile-card">
        <summary><span class="admin-mobile-user"><span class="admin-mobile-avatar" :style="{ backgroundColor: avatarBackground(account.account_id), color: avatarForeground(account.account_id) }" aria-hidden="true">{{ avatarInitials(account.display_name) }}</span><span><strong>{{ account.display_name }}</strong><small>@{{ account.login }}</small></span></span><span class="admin-mobile-meta"><span>{{ account.role === 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь' }}</span><span :class="account.blocked ? 'is-blocked' : 'is-active'">{{ account.blocked ? 'Заблокирован' : 'Активен' }}</span></span><svg class="admin-mobile-menu-mark" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" aria-hidden="true"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg><span class="gc-sr-only">Управление аккаунтом</span></summary>
        <div class="admin-mobile-edit">
          <label>Роль<select v-model="drafts[account.account_id].role" :disabled="busyID === account.account_id" :aria-label="`Роль: ${account.login}`"><option value="MEMBER">Участник</option><option value="ADMINISTRATOR">Администратор</option></select></label>
          <label class="admin-block-toggle"><input v-model="drafts[account.account_id].blocked" type="checkbox" :disabled="busyID === account.account_id" :aria-label="`Заблокирован: ${account.login}`"> Заблокирован</label>
          <div class="admin-mobile-actions"><button type="button" :disabled="busyID === account.account_id" @click="save(account, $event)">Сохранить</button><button type="button" :disabled="busyID === account.account_id" @click="createReset(account, $event)">Сбросить пароль</button></div>
        </div>
      </details>
    </div>
    <section v-if="resetLink" ref="resetResult" class="admin-reset-result" role="dialog" aria-modal="false" aria-labelledby="reset-link-title" @keydown.esc.stop.prevent="closeReset">
      <header><h3 id="reset-link-title">Одноразовая ссылка для @{{ resetLink.login }}</h3><button type="button" aria-label="Закрыть и удалить ссылку" @click="closeReset">×</button></header>
      <p>Покажите ссылку пользователю. После закрытия она будет удалена с этого экрана.</p>
      <input :value="resetLink.url" readonly aria-label="Одноразовая ссылка сброса пароля">
      <p>Истекает: <time :datetime="resetLink.expires_at">{{ new Date(resetLink.expires_at).toLocaleString('ru-RU') }}</time></p>
      <button type="button" @click="copyResetLink">Скопировать ссылку</button>
    </section>
    <button v-if="cursor" class="admin-more" type="button" :disabled="loading" @click="load(cursor)">Загрузить ещё</button>
    <p v-if="status" class="admin-status" aria-live="polite">{{ status }}</p><p v-if="error" class="admin-error" role="alert">{{ error }}</p>
  </section>
</template>
