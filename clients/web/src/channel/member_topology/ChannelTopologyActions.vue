<script setup lang="ts">
import { nextTick, ref } from 'vue'
import type { PermissionValues } from '../../authorization/permission_keys'
import { usePermissionStore } from '../../authorization/permission_store'
import { validCodePointLength } from '../../validation/unicode_limits/unicode_limits'
import type { ChannelTopology, TopologyCategory, TopologyChannel, ChannelKind } from '../topology_client'
import type { VoiceRoomRoster } from '../../voice/voice_roster_client'
import type { VoiceNavigationPresence } from '../voice_navigation_presence'
import ChannelNavigation from '../ChannelNavigation.vue'
import { archiveText, closeVoice, createMemberCategory, createMemberChannel, deleteCategory, TopologyMutationError } from './member_topology_client'

const props = defineProps<{ activeVoiceChannelId?: string; selectedChannelId?: string; topology: ChannelTopology; permissions: PermissionValues; voicePresence: VoiceNavigationPresence | null; voiceRosters?: VoiceRoomRoster[] | null }>()
const emit = defineEmits<{ select: [channel: TopologyChannel]; changed: [] }>()
const permissionStore = usePermissionStore()
const open = ref(false); const name = ref(''); const kind = ref<'CATEGORY' | ChannelKind>('TEXT'); const categoryId = ref('')
const busy = ref(false); const error = ref(''); const status = ref(''); const nameInput = ref<HTMLInputElement | null>(null)
let requestId = ''; const retryKeys = new Map<string, string>()
function id(): string { return crypto.randomUUID() }
function permittedKinds(): Array<'CATEGORY' | ChannelKind> {
  return [props.permissions['category.create'] && 'CATEGORY', props.permissions['channel.text.create'] && 'TEXT', props.permissions['channel.voice.create'] && 'VOICE'].filter(Boolean) as Array<'CATEGORY' | ChannelKind>
}
function begin(category?: TopologyCategory): void {
  const available = permittedKinds(); kind.value = category ? (available.includes('TEXT') ? 'TEXT' : 'VOICE') : available[0] ?? 'CATEGORY'
  categoryId.value = category?.id ?? props.topology.categories[0]?.id ?? ''; name.value = ''; error.value = ''; status.value = ''; requestId = id(); open.value = true
  void nextTick(() => nameInput.value?.focus())
}
function changedIntent(): void { requestId = id(); error.value = ''; status.value = '' }
function close(): void { if (!busy.value) open.value = false }
async function submit(): Promise<void> {
  if (!name.value.trim() || !validCodePointLength(name.value, 1, 80)) { error.value = 'Введите имя до 80 символов.'; return }
  if (kind.value !== 'CATEGORY' && !categoryId.value) { error.value = 'Сначала создайте категорию.'; return }
  busy.value = true; error.value = ''
  try {
    if (kind.value === 'CATEGORY') await createMemberCategory(name.value, requestId)
    else await createMemberChannel(categoryId.value, name.value, kind.value, requestId)
    status.value = 'Изменение принято. Обновляем каналы.'; open.value = false; emit('changed')
  } catch (cause) { await failed(cause) } finally { busy.value = false }
}
async function failed(cause: unknown): Promise<void> {
  error.value = cause instanceof Error ? cause.message : 'Не удалось изменить каналы.'
  if (cause instanceof TopologyMutationError && cause.status === 403) await permissionStore.refresh()
  if (cause instanceof TopologyMutationError && cause.status === 409) emit('changed')
}
async function remove(target: TopologyCategory | TopologyChannel): Promise<void> {
  const channel = 'kind' in target; const action = channel && target.kind === 'VOICE' ? 'Закрыть' : channel ? 'Архивировать' : 'Удалить'
  if (!window.confirm(`${action} «${target.name}»?`)) return
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
  <ChannelNavigation :active-voice-channel-id="activeVoiceChannelId" :selected-channel-id="selectedChannelId" :topology="topology" :permissions="permissions" :voice-presence="voicePresence" :voice-rosters="voiceRosters" @select="emit('select', $event)" @create-global="begin()" @create-in-category="begin" @delete-category="remove" @delete-channel="remove" />
  <div v-if="open" class="topology-dialog-backdrop" @click.self="close"><form class="topology-dialog" role="dialog" aria-modal="true" aria-labelledby="topology-create-title" @submit.prevent="submit" @keydown.esc.prevent="close">
    <h2 id="topology-create-title">Создать</h2>
    <label>Тип<select v-model="kind" :disabled="busy" @change="changedIntent"><option v-for="option in permittedKinds()" :key="option" :value="option">{{ option === 'CATEGORY' ? 'Категория' : option === 'TEXT' ? 'Текстовый канал' : 'Голосовой канал' }}</option></select></label>
    <label v-if="kind !== 'CATEGORY'">Категория<select v-model="categoryId" :disabled="busy" @change="changedIntent"><option v-for="category in topology.categories" :key="category.id" :value="category.id">{{ category.name }}</option></select></label>
    <label>Имя<input ref="nameInput" v-model="name" :disabled="busy" maxlength="80" required @input="changedIntent"></label>
    <p v-if="kind !== 'CATEGORY' && !topology.categories.length" class="topology-action-error">Сначала создайте категорию.</p><p v-if="error" class="topology-action-error" role="alert">{{ error }}</p>
    <div class="topology-dialog-actions"><button type="button" :disabled="busy" @click="close">Отмена</button><button type="submit" :disabled="busy || (kind !== 'CATEGORY' && !categoryId)">{{ busy ? 'Создаём…' : 'Создать' }}</button></div>
  </form></div>
</template>
