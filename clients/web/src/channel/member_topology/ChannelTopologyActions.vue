<script setup lang="ts">
import { nextTick, ref } from 'vue'
import type { PermissionValues } from '../../authorization/permission_keys'
import { usePermissionStore } from '../../authorization/permission_store'
import { validCodePointLength } from '../../validation/unicode_limits/unicode_limits'
import type { ChannelTopology, TopologyCategory, TopologyChannel, ChannelKind } from '../topology_client'
import type { VoiceRoomRoster } from '../../voice/voice_roster_client'
import type { VoiceNavigationPresence } from '../voice_navigation_presence'
import ChannelNavigation from '../ChannelNavigation.vue'
import AdminConfirmation from '../AdminConfirmation.vue'
import { archiveText, closeVoice, createMemberCategory, createMemberChannel, deleteCategory, TopologyMutationError } from './member_topology_client'

const props = defineProps<{ activeVoiceChannelId?: string; selectedChannelId?: string; topology: ChannelTopology; permissions: PermissionValues; voicePresence: VoiceNavigationPresence | null; voiceRosters?: VoiceRoomRoster[] | null }>()
const emit = defineEmits<{ select: [channel: TopologyChannel]; changed: [] }>()
const permissionStore = usePermissionStore()
const open = ref(false); const name = ref(''); const kind = ref<'CATEGORY' | ChannelKind>('TEXT'); const categoryId = ref('')
const busy = ref(false); const error = ref(''); const status = ref(''); const nameInput = ref<HTMLInputElement | null>(null)
const dialogForm = ref<HTMLFormElement | null>(null); const opener = ref<HTMLElement | null>(null)
const confirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null); const confirmationLabel = ref('Подтвердить')
let requestId = ''; const retryKeys = new Map<string, string>()
function id(): string { return crypto.randomUUID() }
function permittedKinds(): Array<'CATEGORY' | ChannelKind> {
  return [props.permissions['category.create'] && 'CATEGORY', props.permissions['channel.text.create'] && 'TEXT', props.permissions['channel.voice.create'] && 'VOICE'].filter(Boolean) as Array<'CATEGORY' | ChannelKind>
}
function begin(category?: TopologyCategory): void {
  opener.value = document.activeElement instanceof HTMLElement ? document.activeElement : null
  const available = permittedKinds(); kind.value = category ? (available.includes('TEXT') ? 'TEXT' : 'VOICE') : available[0] ?? 'CATEGORY'
  categoryId.value = category?.id ?? props.topology.categories[0]?.id ?? ''; name.value = ''; error.value = ''; status.value = ''; requestId = id(); open.value = true
  void nextTick(() => nameInput.value?.focus())
}
function changedIntent(): void { requestId = id(); error.value = ''; status.value = '' }
function close(force = false): void { if (busy.value && !force) return; open.value = false; void nextTick(() => opener.value?.focus()) }
function containTab(event: KeyboardEvent): void {
  if (event.key !== 'Tab') return
  const items = [...(dialogForm.value?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), select:not(:disabled)') ?? [])].filter((item) => item.offsetParent !== null)
  const first = items[0]; const last = items.at(-1)
  if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus() }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() }
}
async function submit(): Promise<void> {
  if (!name.value.trim() || !validCodePointLength(name.value, 1, 80)) { error.value = 'Введите имя до 80 символов.'; return }
  if (kind.value !== 'CATEGORY' && !categoryId.value) { error.value = 'Сначала создайте категорию.'; return }
  busy.value = true; error.value = ''
  try {
    if (kind.value === 'CATEGORY') await createMemberCategory(name.value, requestId)
    else await createMemberChannel(categoryId.value, name.value, kind.value, requestId)
    status.value = 'Изменение принято. Обновляем каналы.'; close(true); emit('changed')
  } catch (cause) { await failed(cause) } finally { busy.value = false }
}
async function failed(cause: unknown): Promise<void> {
  error.value = cause instanceof Error ? cause.message : 'Не удалось изменить каналы.'
  if (cause instanceof TopologyMutationError && cause.status === 403) await permissionStore.refresh()
  if (cause instanceof TopologyMutationError && cause.status === 409) emit('changed')
}
async function remove(target: TopologyCategory | TopologyChannel): Promise<void> {
  const channel = 'kind' in target; const action = channel && target.kind === 'VOICE' ? 'Закрыть' : channel ? 'Архивировать' : 'Удалить'
  confirmationLabel.value = action
  const outcome = !channel ? 'Пустой раздел будет удалён.' : target.kind === 'TEXT' ? 'Канал скроется из списка, а история сообщений сохранится.' : 'Участники будут отключены от голосового канала.'
  if (!await confirmation.value?.ask(`${action} «${target.name}»? ${outcome} Это действие нельзя отменить.`)) return
  const signature = `${channel ? target.kind : 'CATEGORY'}:${target.id}:${props.topology.revision}`; const commandId = retryKeys.get(signature) ?? id(); retryKeys.set(signature, commandId); busy.value = true; error.value = ''
  try {
    if (!channel) await deleteCategory(target.id, props.topology.revision, commandId)
    else if (target.kind === 'TEXT') await archiveText(target.id, props.topology.revision, commandId)
    else await closeVoice(target.id, props.topology.revision, commandId)
    retryKeys.delete(signature); status.value = channel && target.kind === 'VOICE' ? 'Закрытие голосового канала принято.' : 'Изменение выполнено.'; emit('changed')
  } catch (cause) { await failed(cause) } finally { busy.value = false }
}
</script>

<template>
  <p v-if="status" class="topology-action-status" aria-live="polite">{{ status }}</p><p v-if="error" class="topology-action-error" role="alert">{{ error }}</p>
  <ChannelNavigation :active-voice-channel-id="activeVoiceChannelId" :selected-channel-id="selectedChannelId" :topology="topology" :permissions="permissions" :voice-presence="voicePresence" :voice-rosters="voiceRosters" @select="emit('select', $event)" @create-global="begin()" @create-in-category="begin" @delete-category="remove" @delete-channel="remove" @changed="emit('changed')" />
  <AdminConfirmation ref="confirmation" id="member-topology-confirm" title="Подтвердите действие" :confirm-label="confirmationLabel" />
  <Teleport to="body"><div v-if="open" class="topology-dialog-backdrop" @click.self="close()"><form ref="dialogForm" class="topology-dialog" role="dialog" aria-modal="true" aria-labelledby="topology-create-title" @submit.prevent="submit" @keydown.esc.prevent="close()" @keydown="containTab">
    <header><div><h2 id="topology-create-title">{{ kind === 'CATEGORY' ? 'Создать раздел' : 'Создать канал' }}</h2><p>Новое место для общения в вашей гильдии</p></div><button type="button" aria-label="Закрыть" :disabled="busy" @click="close()">×</button></header>
    <label>{{ kind === 'CATEGORY' ? 'Тип раздела' : 'Тип канала' }}<select v-model="kind" :disabled="busy" @change="changedIntent"><option v-for="option in permittedKinds()" :key="option" :value="option">{{ option === 'CATEGORY' ? 'Раздел' : option === 'TEXT' ? 'Текстовый' : 'Голосовой' }}</option></select></label>
    <label v-if="kind !== 'CATEGORY'">Раздел<select v-model="categoryId" :disabled="busy" @change="changedIntent"><option v-for="category in topology.categories" :key="category.id" :value="category.id">{{ category.name }}</option></select></label>
    <label>{{ kind === 'CATEGORY' ? 'Название раздела' : 'Название канала' }}<input ref="nameInput" v-model="name" :disabled="busy" maxlength="80" required @input="changedIntent"></label>
    <p v-if="kind !== 'CATEGORY'" class="topology-dialog-note">Канал будет доступен участникам гильдии согласно их ролям.</p>
    <p v-if="kind !== 'CATEGORY' && !topology.categories.length" class="topology-action-error">Сначала создайте раздел.</p><p v-if="error" class="topology-action-error" role="alert">{{ error }}</p>
    <div class="topology-dialog-actions"><button type="button" :disabled="busy" @click="close()">Отмена</button><button type="submit" :disabled="busy || (kind !== 'CATEGORY' && !categoryId)">{{ busy ? 'Создаём…' : kind === 'CATEGORY' ? 'Создать раздел' : 'Создать канал' }}</button></div>
  </form></div></Teleport>
</template>
