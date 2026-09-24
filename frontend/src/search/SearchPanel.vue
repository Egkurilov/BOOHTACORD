<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import MessageBody from '../conversation/MessageBody.vue'
import { searchMessages, type SearchMessage } from './search_messages_client'

interface SearchConversation { id: string; kind: 'CHANNEL' | 'DIRECT_MESSAGE'; label: string }
const props = defineProps<{ currentConversation: SearchConversation | null; channelLabels: Record<string, string>; directMessageLabels: Record<string, string> }>()
const emit = defineEmits<{ open: [message: SearchMessage]; close: [] }>()
const query = ref('')
const scope = ref<'all' | 'current'>(props.currentConversation ? 'current' : 'all')
const messages = ref<SearchMessage[]>([])
const nextCursor = ref('')
const activeQuery = ref('')
const loading = ref(false)
const searched = ref(false)
const error = ref('')
const queryInput = ref<HTMLInputElement | null>(null)
let requestSequence = 0
const canSubmit = computed(() => !loading.value && Boolean(query.value.trim()) && (scope.value === 'all' || Boolean(props.currentConversation)))

function reset(): void { requestSequence++; messages.value = []; nextCursor.value = ''; activeQuery.value = ''; loading.value = false; searched.value = false; error.value = '' }
watch(scope, reset)
watch(() => props.currentConversation?.id, () => { if (scope.value === 'current') { if (!props.currentConversation) scope.value = 'all'; else reset() } })

async function runSearch(before?: string): Promise<void> {
  const searchQuery = before ? activeQuery.value : query.value
  if (!searchQuery.trim() || !canSubmit.value && !before) return
  const conversation = scope.value === 'current' ? props.currentConversation : null
  if (scope.value === 'current' && !conversation) { error.value = 'Выберите беседу или ищите по всем беседам.'; return }
  const sequence = ++requestSequence
  loading.value = true
  error.value = ''
  try {
    const page = await searchMessages({ query: searchQuery, ...(conversation?.kind === 'CHANNEL' ? { channelId: conversation.id } : {}), ...(conversation?.kind === 'DIRECT_MESSAGE' ? { directMessageId: conversation.id } : {}), before })
    if (sequence !== requestSequence) return
    messages.value = before ? [...messages.value, ...page.messages] : page.messages
    nextCursor.value = page.nextCursor ?? ''
    activeQuery.value = searchQuery
    searched.value = true
  } catch (reason) {
    if (sequence === requestSequence) error.value = reason instanceof Error ? reason.message : 'Не удалось выполнить поиск сообщений.'
  } finally { if (sequence === requestSequence) loading.value = false }
}

function conversationLabel(message: SearchMessage): string {
  return message.kind === 'CHANNEL' ? props.channelLabels[message.channelId] ?? 'Текстовый канал' : props.directMessageLabels[message.directMessageId] ?? 'Личный диалог'
}
function formattedDate(value: string): string { return new Intl.DateTimeFormat('ru-RU', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(value)) }
onBeforeUnmount(() => { requestSequence++ })
onMounted(() => { void nextTick(() => queryInput.value?.focus()) })
</script>

<template>
  <section class="search-panel" aria-labelledby="search-panel-title" data-testid="search-panel">
    <header class="search-panel-heading"><div><p class="search-eyebrow">ПОИСК</p><h1 id="search-panel-title">Поиск сообщений</h1><p>По общим каналам и личным диалогам, доступным вашей учётной записи.</p></div><button class="search-close" type="button" aria-label="Закрыть поиск" @click="emit('close')">×</button></header>
    <form class="search-form" role="search" @submit.prevent="runSearch()">
      <label>Запрос<input ref="queryInput" v-model="query" type="search" autocomplete="off" maxlength="256" placeholder="Слова или «точная фраза»" :disabled="loading"></label>
      <label>Область поиска<select v-model="scope" :disabled="loading"><option value="all">Все беседы</option><option v-if="currentConversation" value="current">Текущая беседа: {{ currentConversation.label }}</option></select></label>
      <button class="search-submit" type="submit" :disabled="!canSubmit">{{ loading ? 'Ищем…' : 'Найти' }}</button>
    </form>
    <p v-if="error" class="search-error" role="alert">{{ error }}</p>
    <p class="search-status" aria-live="polite" :aria-busy="loading">{{ loading ? 'Ищем сообщения…' : searched ? (messages.length ? `Результатов: ${messages.length}.` : 'Совпадений нет.') : 'Введите запрос и нажмите «Найти».' }}</p>
    <ol v-if="messages.length" class="search-results" aria-label="Результаты поиска">
      <li v-for="message in messages" :key="`${message.kind}:${message.id}`" class="search-result">
        <article><header><strong>{{ conversationLabel(message) }}</strong><time :datetime="message.createdAt">{{ formattedDate(message.createdAt) }}</time></header><MessageBody :body="message.body" /><button type="button" @click="emit('open', message)">Открыть беседу</button></article>
      </li>
    </ol>
    <button v-if="nextCursor" class="search-more" type="button" :disabled="loading" @click="runSearch(nextCursor)">Показать ещё</button>
  </section>
</template>
