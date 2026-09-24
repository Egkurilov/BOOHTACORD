<script setup lang="ts">
import { computed } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import { useWorkspaceVoiceControls } from '../workspace/voice_controls'
import SearchPanel from './SearchPanel.vue'
import type { SearchMessage } from './search_messages_client'

const emit = defineEmits<{ openChannel: [channel: TopologyChannel]; openDirectMessage: [id: string]; close: [] }>()
const voice = useWorkspaceVoiceControls()
const directMessageStore = useDirectMessageStore()
const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)
const currentConversation = computed(() => selectedDirectMessage.value
  ? { id: selectedDirectMessage.value.id, kind: 'DIRECT_MESSAGE' as const, label: selectedDirectMessage.value.otherParticipantDisplayName }
  : voice.selectedChannel.value?.kind === 'TEXT' ? { id: voice.selectedChannel.value.id, kind: 'CHANNEL' as const, label: `# ${voice.selectedChannel.value.name}` } : null)
const channelLabels = computed(() => Object.fromEntries((voice.topologyStore.topology?.categories ?? []).flatMap((category) => category.channels.filter((channel) => channel.kind === 'TEXT').map((channel) => [channel.id, `# ${channel.name}`]))))
const directMessageLabels = computed(() => Object.fromEntries(directMessageStore.directMessages.map((item) => [item.id, item.otherParticipantDisplayName])))
function open(message: SearchMessage): void {
  if (message.kind === 'CHANNEL') {
    const channel = voice.topologyStore.topology?.categories.flatMap((category) => category.channels).find((item) => item.id === message.channelId && item.kind === 'TEXT')
    if (channel) emit('openChannel', channel)
  } else emit('openDirectMessage', message.directMessageId)
}
</script>

<template>
  <SearchPanel :current-conversation="currentConversation" :channel-labels="channelLabels" :direct-message-labels="directMessageLabels" @open="open" @close="emit('close')" />
</template>
