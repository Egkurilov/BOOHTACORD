<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import type { TopologyChannel } from '../../channel/topology_client'
import { useDirectMessageStore } from '../../direct_message/direct_message_store'
import { useWorkspaceVoiceControls } from '../voice_controls'
import SearchPanel from '../../search/SearchPanel.vue'
import type { SearchMessage } from '../../search/search_messages_client'
import { useSearchTargetStore } from '../../search/search_target_store'
import QuickJumpPanel from '../../search/QuickJumpPanel.vue'
import type { QuickJumpTarget } from '../../search/quick_jump'

const emit = defineEmits<{ openChannel: [channel: TopologyChannel]; openDirectMessage: [id: string]; close: [] }>()
const voice = useWorkspaceVoiceControls()
const directMessageStore = useDirectMessageStore()
const searchTarget = useSearchTargetStore()
const openError = ref('')
const searchMode = ref<'messages' | 'navigation'>('messages')
let openSequence = 0
const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)
const currentConversation = computed(() => selectedDirectMessage.value
  ? { id: selectedDirectMessage.value.id, kind: 'DIRECT_MESSAGE' as const, label: selectedDirectMessage.value.otherParticipantDisplayName }
  : voice.selectedChannel.value?.kind === 'TEXT' ? { id: voice.selectedChannel.value.id, kind: 'CHANNEL' as const, label: `#${voice.selectedChannel.value.name}` } : null)
const channelLabels = computed(() => Object.fromEntries((voice.topologyStore.topology?.categories ?? []).flatMap((category) => category.channels.filter((channel) => channel.kind === 'TEXT').map((channel) => [channel.id, `#${channel.name}`]))))
const directMessageLabels = computed(() => Object.fromEntries(directMessageStore.directMessages.map((item) => [item.id, item.otherParticipantDisplayName])))
const navigationChannels = computed(() => voice.topologyStore.topology?.categories.flatMap((category) => category.channels) ?? [])
const navigationPeople = computed(() => directMessageStore.directMessages.map((item) => ({ id: item.id, displayName: item.otherParticipantDisplayName })))
const navigationStatus = computed(() => voice.topologyStore.loading || directMessageStore.loadingNavigation ? 'Загружаем каналы и людей…' : voice.topologyStore.error || directMessageStore.error ? 'Не удалось обновить список. Повторите попытку.' : !voice.topologyStore.topology ? 'Список каналов пока недоступен.' : '')
async function open(message: SearchMessage): Promise<void> {
  const sequence = ++openSequence
  openError.value = ''
  if (message.kind === 'CHANNEL') {
    let channel = voice.topologyStore.topology?.categories.flatMap((category) => category.channels).find((item) => item.id === message.channelId && item.kind === 'TEXT')
    if (!channel) { await voice.topologyStore.refresh(); if (sequence !== openSequence) return; channel = voice.topologyStore.topology?.categories.flatMap((category) => category.channels).find((item) => item.id === message.channelId && item.kind === 'TEXT') }
    if (!channel) { openError.value = 'Найденный канал больше недоступен.'; return }
    searchTarget.open({ kind: 'CHANNEL', conversationId: channel.id, messageId: message.id })
    emit('openChannel', channel)
  } else {
    if (!directMessageStore.directMessages.some(({ id }) => id === message.directMessageId)) { await directMessageStore.refreshNavigation(); if (sequence !== openSequence) return }
    if (!directMessageStore.directMessages.some(({ id }) => id === message.directMessageId)) { openError.value = 'Личный диалог больше недоступен.'; return }
    searchTarget.open({ kind: 'DIRECT_MESSAGE', conversationId: message.directMessageId, messageId: message.id })
    emit('openDirectMessage', message.directMessageId)
  }
}
async function openQuickJump(entry: QuickJumpTarget): Promise<void> {
  const sequence = ++openSequence
  openError.value = ''
  if (entry.kind === 'CHANNEL') {
    let channel = voice.topologyStore.topology?.categories.flatMap((category) => category.channels).find((item) => item.id === entry.id && item.kind === 'TEXT')
    if (!channel) { await voice.topologyStore.refresh(); if (sequence !== openSequence) return; channel = voice.topologyStore.topology?.categories.flatMap((category) => category.channels).find((item) => item.id === entry.id && item.kind === 'TEXT') }
    if (!channel) { openError.value = 'Текстовый канал больше недоступен.'; return }
    emit('openChannel', channel)
  } else {
    if (!directMessageStore.directMessages.some(({ id }) => id === entry.id)) { await directMessageStore.refreshNavigation(); if (sequence !== openSequence) return }
    if (!directMessageStore.directMessages.some(({ id }) => id === entry.id)) { openError.value = 'Личный диалог больше недоступен.'; return }
    emit('openDirectMessage', entry.id)
  }
}
onBeforeUnmount(() => { openSequence++ })
</script>

<template>
  <div class="workspace-search-modes" role="group" aria-label="Тип поиска">
    <button type="button" :aria-pressed="searchMode === 'messages'" @click="searchMode = 'messages'">Сообщения</button>
    <button type="button" :aria-pressed="searchMode === 'navigation'" @click="searchMode = 'navigation'">Каналы и люди</button>
    <button v-if="searchMode === 'navigation'" type="button" aria-label="Закрыть поиск" @click="emit('close')">Закрыть</button>
  </div>
  <SearchPanel v-show="searchMode === 'messages'" :current-conversation="currentConversation" :channel-labels="channelLabels" :direct-message-labels="directMessageLabels" @open="open" @close="emit('close')" />
  <QuickJumpPanel v-if="searchMode === 'navigation'" :channels="navigationChannels" :people="navigationPeople" :status="navigationStatus" @select="openQuickJump" />
  <p v-if="openError" class="search-error" role="alert">{{ openError }}</p>
</template>

<style scoped>
.workspace-search-modes { display: flex; gap: 8px; margin: 12px 20px 0; }
.workspace-search-modes button { background: transparent; border: 1px solid var(--gc-border, #363a46); border-radius: 999px; color: inherit; cursor: pointer; min-height: 36px; padding: 6px 12px; }
.workspace-search-modes button[aria-pressed="true"] { background: var(--gc-surface-raised, #20232d); border-color: var(--gc-accent, #6974f5); }
@media (max-width: 600px) { .workspace-search-modes { margin-inline: 16px; } }
</style>
