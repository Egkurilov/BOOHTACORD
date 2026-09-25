<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import type { CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import MessageItem from './MessageItem.vue'
import { chronologicalDatedMessages } from './history_dates'
import { createMessageLogAnnouncer } from './message_log_announcement'
import { groupChronologicalMessages } from './message_grouping'
import { isHistoryNearBottom, newestServerMessageId, newServerMessageCount } from './new_message_jump'
import type { TextMessage } from './message_client'
import { useMessageStore } from './message_store'

const props = defineProps<{ channelId: string; session: CurrentSession | null }>()
const emit = defineEmits<{ reply: [message: TextMessage]; retry: [message: TextMessage]; viewportChange: [] }>()
const store = useMessageStore()
const authors = useAuthorDirectory()
const list = ref<HTMLOListElement | null>(null)
const chronologicalMessages = computed(() => groupChronologicalMessages(chronologicalDatedMessages(store.messages)))
const announceNew = createMessageLogAnnouncer()
const announcement = ref('')
const jumpCount = ref(0)
const latestServerId = computed(() => newestServerMessageId(store.messages))
let announcementVersion = 0

watch([() => props.channelId, () => store.channelId, () => store.historyLoaded, () => store.messages, () => props.session?.accountId], async () => {
  const text = announceNew({ conversationId: props.channelId, loaded: store.historyLoaded && store.channelId === props.channelId,
    active: typeof document !== 'undefined' && document.visibilityState === 'visible', ownId: props.session?.accountId ?? '',
    messages: store.messages, displayName: (id) => authors.displayName(id) })
  const version = ++announcementVersion
  announcement.value = ''
  if (!text) return
  await nextTick()
  if (version === announcementVersion) announcement.value = text
}, { immediate: true, flush: 'post' })

onMounted(() => { if (list.value) list.value.scrollTop = list.value.scrollHeight; emit('viewportChange') })
watch(() => props.channelId, async () => { jumpCount.value = 0; await nextTick(); if (list.value) list.value.scrollTop = list.value.scrollHeight; emit('viewportChange') })
watch([() => store.historyLoaded, latestServerId], async ([loaded, newest], [wasLoaded, previous]) => {
  const viewport = list.value
  if (!newest || !viewport || store.channelId !== props.channelId) return
  const nearBottom = isHistoryNearBottom(viewport)
  const added = newServerMessageCount(store.messages, previous, wasLoaded)
  await nextTick()
  if (nearBottom) { viewport.scrollTop = viewport.scrollHeight; jumpCount.value = 0 }
  else if (loaded) jumpCount.value += added
  emit('viewportChange')
})

function onScroll(): void { if (isHistoryNearBottom(list.value)) jumpCount.value = 0; emit('viewportChange') }
function jumpToLatest(): void { if (!list.value) return; list.value.scrollTop = list.value.scrollHeight; jumpCount.value = 0; emit('viewportChange') }

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
  if (!viewport || channelId !== props.channelId) return
  if (anchorId && anchorTop !== undefined) {
    const current = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find((item) => item.dataset.messageId === anchorId)
    if (current) viewport.scrollTop += current.getBoundingClientRect().top - anchorTop
  }
  emit('viewportChange')
}
</script>

<template>
  <p class="gc-sr-only" role="status" aria-atomic="true">{{ announcement }}</p>
  <div class="message-history-wrap">
  <button v-if="jumpCount" class="message-jump-latest" type="button" @click="jumpToLatest">К новым сообщениям ({{ jumpCount }})</button>
  <ol ref="list" class="messages message-list" role="log" aria-live="off" aria-label="История сообщений" @scroll.passive="onScroll">
    <li v-if="store.nextCursor" class="message-actions"><button type="button" :disabled="store.olderLoading" @click="loadOlder">{{ store.olderLoading ? 'Загружаем старые сообщения…' : 'Показать предыдущие сообщения' }}</button></li>
    <li v-if="store.olderError" class="state state-error" role="alert">{{ store.olderError }} <button type="button" :disabled="store.olderLoading" @click="loadOlder">Повторить</button></li>
    <template v-for="(entry, index) in chronologicalMessages" :key="entry.message.id">
    <li v-if="entry.dateLabel" class="history-date"><span v-if="store.historyLoaded && !store.nextCursor && index === 0" class="history-start" role="status" aria-label="Это начало истории.">Начало</span><time :datetime="entry.dateTime">{{ entry.dateLabel }}</time></li>
    <li :data-message-id="entry.message.id" :class="{ 'grouped-message': entry.grouped }">
      <MessageItem
        :message="entry.message"
        :grouped="entry.grouped"
        :reply-preview="replyPreview(entry.message)"
        :can-edit="session?.accountId === entry.message.authorId"
        :can-delete="session?.accountId === entry.message.authorId || session?.role === 'ADMINISTRATOR'"
        :retry-disabled="store.sending"
        :edit-message="(body, ids, revision) => store.editWithResult(entry.message.id, body, revision, undefined, ids)"
        :refresh-message="() => store.refreshMessage(entry.message.id)"
        @remove="store.remove(entry.message.id)"
        @reply="emit('reply', entry.message)"
        @retry="emit('retry', entry.message)"
      />
    </li>
    </template>
    <li v-if="!store.messages.length && !store.loading" class="state">Сообщений пока нет.</li>
  </ol>
  </div>
</template>
