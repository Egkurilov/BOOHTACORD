<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import { useWorkspaceVoiceControls } from '../workspace/voice_controls'
import SearchPanel from './SearchPanel.vue'
import type { SearchMessage } from './search_messages_client'
import { useSearchTargetStore } from './search_target_store'

const emit = defineEmits<{ openChannel: [channel: TopologyChannel]; openDirectMessage: [id: string]; close: [] }>()
const voice = useWorkspaceVoiceControls()
const directMessageStore = useDirectMessageStore()
const searchTarget = useSearchTargetStore()
const openError = ref('')
let openSequence = 0
const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)
const currentConversation = computed(() => selectedDirectMessage.value
  ? { id: selectedDirectMessage.value.id, kind: 'DIRECT_MESSAGE' as const, label: selectedDirectMessage.value.otherParticipantDisplayName }
  : voice.selectedChannel.value?.kind === 'TEXT' ? { id: voice.selectedChannel.value.id, kind: 'CHANNEL' as const, label: `# ${voice.selectedChannel.value.name}` } : null)
const channelLabels = computed(() => Object.fromEntries((voice.topologyStore.topology?.categories ?? []).flatMap((category) => category.channels.filter((channel) => channel.kind === 'TEXT').map((channel) => [channel.id, `# ${channel.name}`]))))
const directMessageLabels = computed(() => Object.fromEntries(directMessageStore.directMessages.map((item) => [item.id, item.otherParticipantDisplayName])))
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
onBeforeUnmount(() => { openSequence++ })
</script>

<template>
  <SearchPanel :current-conversation="currentConversation" :channel-labels="channelLabels" :direct-message-labels="directMessageLabels" @open="open" @close="emit('close')" />
  <p v-if="openError" class="search-error" role="alert">{{ openError }}</p>
</template>
