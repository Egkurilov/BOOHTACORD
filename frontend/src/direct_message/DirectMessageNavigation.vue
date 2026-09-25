<script setup lang="ts">
import type { DirectMessageListItem } from './direct_message_client'
import DirectMessageStarter from './DirectMessageStarter.vue'

const props = defineProps<{
  directMessages: DirectMessageListItem[]
  error: string | null
  loading: boolean
  selectedDirectMessageId?: string
}>()

const emit = defineEmits<{ select: [directMessageId: string]; open: [directMessageId: string] }>()

function initial(displayName: string): string {
  return displayName.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У'
}
</script>

<template>
  <nav class="direct-message-navigation" aria-label="Личные сообщения">
    <h2>Личные сообщения</h2>
    <DirectMessageStarter @open="emit('open', $event)" />
    <p v-if="props.loading" class="empty-category" aria-live="polite">Загружаем диалоги…</p>
    <p v-else-if="props.error" class="empty-category state-error" role="alert">{{ props.error }}</p>
    <p v-else-if="!props.directMessages.length" class="empty-category">Диалогов пока нет.</p>
    <button
      v-for="directMessage in props.directMessages"
      :key="directMessage.id"
      class="channel-button"
      :class="{ selected: props.selectedDirectMessageId === directMessage.id }"
      :aria-current="props.selectedDirectMessageId === directMessage.id ? 'page' : undefined"
      type="button"
      @click="emit('select', directMessage.id)"
    >
      <span class="dm-avatar" aria-hidden="true">{{ initial(directMessage.otherParticipantDisplayName) }}</span>
      <span class="channel-name">{{ directMessage.otherParticipantDisplayName }}</span>
      <span v-if="directMessage.unreadCount" class="channel-state" :aria-label="`Непрочитанных личных сообщений: ${directMessage.unreadCount}`">{{ directMessage.unreadCount }}</span>
      <span v-if="directMessage.mentionCount" class="channel-state" :aria-label="`Упоминаний в личном диалоге: ${directMessage.mentionCount}`">@{{ directMessage.mentionCount }}</span>
    </button>
  </nav>
</template>
