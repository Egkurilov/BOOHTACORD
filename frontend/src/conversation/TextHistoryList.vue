<script setup lang="ts">
import { nextTick, ref } from 'vue'
import type { CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import MessageItem from './MessageItem.vue'
import type { TextMessage } from './message_client'
import { useMessageStore } from './message_store'

const props = defineProps<{ channelId: string; session: CurrentSession | null }>()
const emit = defineEmits<{ reply: [message: TextMessage]; retry: [message: TextMessage] }>()
const store = useMessageStore()
const authors = useAuthorDirectory()
const list = ref<HTMLOListElement | null>(null)

function replyPreview(message: TextMessage): string | undefined {
  if (!message.replyToId) return undefined
  const target = store.messages.find((candidate) => candidate.id === message.replyToId)
  if (!target) return 'Исходное сообщение недоступно'
  return target.deleted ? 'Сообщение удалено' : `${authors.displayName(target.authorId)}: ${target.body.slice(0, 140)}`
}

async function loadOlder(): Promise<void> {
  const viewport = list.value
  const top = viewport?.getBoundingClientRect().top
  const anchor = [...(viewport?.querySelectorAll<HTMLElement>('[data-message-id]') ?? [])].find((item) => item.getBoundingClientRect().bottom > (top ?? 0))
  const anchorId = anchor?.dataset.messageId
  const anchorTop = anchor?.getBoundingClientRect().top
  const channelId = props.channelId
  if (!await store.loadOlder()) return
  await nextTick()
  if (!viewport || channelId !== props.channelId || !anchorId || anchorTop === undefined) return
  const current = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find((item) => item.dataset.messageId === anchorId)
  if (current) viewport.scrollTop += current.getBoundingClientRect().top - anchorTop
}
</script>

<template>
  <ol ref="list" class="messages message-list" aria-label="История сообщений">
    <li v-for="message in store.messages" :key="message.id" :data-message-id="message.id">
      <MessageItem
        :message="message"
        :reply-preview="replyPreview(message)"
        :can-edit="session?.accountId === message.authorId"
        :can-delete="session?.accountId === message.authorId || session?.role === 'ADMINISTRATOR'"
        :retry-disabled="store.sending"
        :edit-message="(body, ids, revision) => store.editWithResult(message.id, body, revision, undefined, ids)"
        :refresh-message="() => store.refreshMessage(message.id)"
        @remove="store.remove(message.id)"
        @reply="emit('reply', message)"
        @retry="emit('retry', message)"
      />
    </li>
    <li v-if="store.nextCursor" class="message-actions"><button type="button" :disabled="store.olderLoading" @click="loadOlder">{{ store.olderLoading ? 'Загружаем старые сообщения…' : 'Показать предыдущие сообщения' }}</button></li>
    <li v-if="store.olderError" class="state state-error" role="alert">{{ store.olderError }} <button type="button" :disabled="store.olderLoading" @click="loadOlder">Повторить</button></li>
    <li v-if="store.historyLoaded && !store.nextCursor && store.messages.length" class="state">Это начало истории.</li>
    <li v-if="!store.messages.length && !store.loading" class="state">Сообщений пока нет.</li>
  </ol>
</template>
