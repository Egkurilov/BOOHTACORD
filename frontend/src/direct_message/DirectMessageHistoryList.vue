<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import MessageItem from '../conversation/MessageItem.vue'
import { useAuthorDirectory } from '../identity/author_directory'
import type { CurrentSession } from '../identity/current_session'
import type { DirectMessageHistoryItem } from './direct_message_client'
import { useDirectMessageStore } from './direct_message_store'

const props = defineProps<{ directMessageId: string; session: CurrentSession | null; otherParticipantId: string; otherParticipantDisplayName: string }>()
const emit = defineEmits<{ reply: [message: DirectMessageHistoryItem]; retry: [message: DirectMessageHistoryItem] }>()
const store = useDirectMessageStore()
const authors = useAuthorDirectory()
const list = ref<HTMLOListElement | null>(null)
watch(() => store.messages, (messages) => {
  for (const message of messages) if (message.replyPreview) void authors.ensure(message.replyPreview.authorId)
}, { immediate: true })

function replyPreview(message: DirectMessageHistoryItem): string | undefined {
  const preview = message.replyPreview
  if (!preview) return undefined
  return preview.deleted ? 'Сообщение удалено' : `${authors.displayName(preview.authorId)}: ${preview.body.slice(0, 140)}`
}

async function loadOlder(): Promise<void> {
  const viewport = list.value
  const top = viewport?.getBoundingClientRect().top
  const anchor = [...(viewport?.querySelectorAll<HTMLElement>('[data-message-id]') ?? [])].find((item) => item.getBoundingClientRect().bottom > (top ?? 0))
  const anchorId = anchor?.dataset.messageId
  const anchorTop = anchor?.getBoundingClientRect().top
  const directMessageId = props.directMessageId
  if (!await store.loadOlder()) return
  await nextTick()
  if (!viewport || directMessageId !== props.directMessageId || !anchorId || anchorTop === undefined) return
  const current = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find((item) => item.dataset.messageId === anchorId)
  if (current) viewport.scrollTop += current.getBoundingClientRect().top - anchorTop
}
</script>

<template>
  <ol ref="list" class="messages message-list" aria-label="История личного диалога">
    <li v-for="message in store.messages" :key="message.id" :data-message-id="message.id">
      <MessageItem
        :message="message"
        :reply-preview="replyPreview(message)"
        :can-edit="session?.accountId === message.authorId"
        :can-delete="session?.accountId === message.authorId"
        :retry-disabled="store.sending"
        :mention-recipient="{ id: props.otherParticipantId, displayName: props.otherParticipantDisplayName }"
        @edit="(body, ids) => store.edit(message.id, body, message.revision, undefined, ids)"
        @remove="store.remove(message.id)"
        @reply="emit('reply', message)"
        @retry="emit('retry', message)"
      />
    </li>
    <li v-if="store.nextCursor" class="message-actions"><button type="button" :disabled="store.olderLoading" @click="loadOlder">{{ store.olderLoading ? 'Загружаем старые сообщения…' : 'Показать предыдущие сообщения' }}</button></li>
    <li v-if="store.olderError" class="state state-error" role="alert">{{ store.olderError }} <button type="button" :disabled="store.olderLoading" @click="loadOlder">Повторить</button></li>
    <li v-if="store.historyLoaded && !store.nextCursor && store.messages.length" class="state">Это начало истории.</li>
    <li v-if="!store.messages.length && !store.loadingHistory" class="state">Сообщений пока нет.</li>
  </ol>
</template>
