<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import MessageBody from './MessageBody.vue'
import { searchTextMessages, type TextMessageSearchResult } from './text_message_search_client'

const props = defineProps<{ channelId: string }>()
const query = ref('')
const activeQuery = ref('')
const messages = ref<TextMessageSearchResult[]>([])
const nextCursor = ref<string | undefined>()
const loading = ref(false)
const searched = ref(false)
const error = ref<string | null>(null)
let requestSequence = 0

const hasQuery = computed(() => query.value.trim().length > 0)
const canLoadMore = computed(() => Boolean(nextCursor.value) && !loading.value && query.value === activeQuery.value)

function reset(): void {
  requestSequence++
  activeQuery.value = ''
  messages.value = []
  nextCursor.value = undefined
  loading.value = false
  searched.value = false
  error.value = null
}

watch(() => props.channelId, reset)

async function runSearch(searchQuery: string, before: string | undefined, append: boolean): Promise<void> {
  if (!searchQuery.trim()) {
    error.value = 'Введите поисковый запрос.'
    return
  }
  const channelId = props.channelId
  const sequence = ++requestSequence
  loading.value = true
  error.value = null
  try {
    const page = await searchTextMessages(channelId, searchQuery, before)
    if (sequence !== requestSequence || channelId !== props.channelId) return
    activeQuery.value = searchQuery
    messages.value = append ? [...messages.value, ...page.messages] : page.messages
    nextCursor.value = page.nextCursor
    searched.value = true
  } catch (cause) {
    if (sequence === requestSequence && channelId === props.channelId) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось выполнить поиск сообщений.'
    }
  } finally {
    if (sequence === requestSequence) loading.value = false
  }
}

function submit(): void {
  void runSearch(query.value, undefined, false)
}

function loadMore(): void {
  if (nextCursor.value) void runSearch(activeQuery.value, nextCursor.value, true)
}
</script>

<template>
  <section class="text-message-search" aria-labelledby="text-search-title">
    <h3 id="text-search-title">Поиск в канале</h3>
    <form class="text-search-form" role="search" @submit.prevent="submit">
      <label>
        Запрос
        <input v-model="query" autocomplete="off" :disabled="loading" maxlength="256" placeholder="Слова или «точная фраза»" type="search">
      </label>
      <button type="submit" :disabled="loading || !hasQuery">{{ loading ? 'Ищем…' : 'Найти' }}</button>
    </form>
    <p v-if="error" class="text-search-error" role="alert">{{ error }}</p>
    <p v-else-if="searched" class="text-search-status" aria-live="polite">
      {{ messages.length ? `Найдено в этой странице: ${messages.length}.` : 'Совпадений нет.' }}
    </p>
    <ol v-if="messages.length" class="text-search-results" aria-label="Результаты поиска">
      <li v-for="message in messages" :key="message.id" class="text-search-result">
        <p class="message-meta">{{ message.authorId }} · {{ new Date(message.createdAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) }}<span v-if="message.editedAt"> · изменено</span></p>
        <MessageBody :body="message.body" />
      </li>
    </ol>
    <button v-if="nextCursor" class="text-search-more" type="button" :disabled="!canLoadMore" @click="loadMore">Показать ещё</button>
    <p v-if="nextCursor && !canLoadMore && !loading" class="text-search-status">Измените запрос или запустите поиск заново.</p>
  </section>
</template>
