<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useAuthorDirectory } from '../identity/author_directory'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import SystemWelcomeMessage from '../conversation/system_welcome/SystemWelcomeMessage.vue'
import SearchResultBody from './SearchResultBody.vue'
import SearchFilters from './filters/SearchFilters.vue'
import { useSearchFilters } from './filters/state'
import { searchDateRange, type SearchDateRange } from './filters/date_range'
import PersonalMentionsPanel from './PersonalMentionsPanel.vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import { searchMessages, type SearchMessage } from './search_messages_client'
import type { MentionInboxItem } from './mentions_inbox_client'

interface SearchConversation { id: string; kind: 'CHANNEL' | 'DIRECT_MESSAGE'; label: string }
const props = defineProps<{ currentConversation: SearchConversation | null; channelLabels: Record<string, string>; directMessageLabels: Record<string, string> }>()
const emit = defineEmits<{ open: [message: SearchMessage]; openMention: [mention: MentionInboxItem]; close: [] }>()
const activeView = ref<'messages' | 'mentions'>('messages')
const filters = useSearchFilters()
const query = ref('')
const scope = ref<'all' | 'current'>('all')
const authors = useAuthorDirectory()
const messages = ref<SearchMessage[]>([])
const nextCursor = ref('')
const activeQuery = ref('')
const activeDates = ref<SearchDateRange>({})
const loading = ref(false)
const searched = ref(false)
const error = ref('')
const queryInput = ref<HTMLInputElement | null>(null)
let requestSequence = 0
const canSubmit = computed(() => !loading.value && Boolean(query.value.trim()) && (scope.value === 'all' || Boolean(props.currentConversation)))

function reset(): void { requestSequence++; messages.value = []; nextCursor.value = ''; activeQuery.value = ''; activeDates.value = {}; loading.value = false; searched.value = false; error.value = '' }
watch(scope, reset)
watch(() => [filters.authorId, filters.attachment, filters.dateFrom, filters.dateTo], reset)
watch(messages, (items) => { for (const item of items) void authors.ensure(item.authorId) })
watch(() => props.currentConversation?.id, () => { if (scope.value === 'current') { if (!props.currentConversation) scope.value = 'all'; else reset() } })

async function runSearch(before?: string): Promise<void> {
  const searchQuery = before ? activeQuery.value : query.value
  if (!searchQuery.trim() || !canSubmit.value && !before) return
  if (!validCodePointLength(searchQuery.trim(), 1, 256)) { error.value = 'Запрос должен содержать до 256 символов.'; return }
  const conversation = scope.value === 'current' ? props.currentConversation : null
  if (scope.value === 'current' && !conversation) { error.value = 'Выберите беседу или ищите по всем беседам.'; return }
  const sequence = ++requestSequence
  loading.value = true
  error.value = ''
  try {
    const dates = before ? activeDates.value : searchDateRange(filters.dateFrom, filters.dateTo)
    const page = await searchMessages({ query: searchQuery, ...dates, ...(conversation?.kind === 'CHANNEL' ? { channelId: conversation.id } : {}), ...(conversation?.kind === 'DIRECT_MESSAGE' ? { directMessageId: conversation.id } : {}), ...(filters.authorId ? { authorId: filters.authorId } : {}), ...(filters.attachment !== 'any' ? { hasAttachment: filters.attachment === 'with' } : {}), before })
    if (sequence !== requestSequence) return
    messages.value = before ? [...messages.value, ...page.messages] : page.messages
    nextCursor.value = page.nextCursor ?? ''
    activeQuery.value = searchQuery
    activeDates.value = dates
    searched.value = true
  } catch (reason) {
    if (sequence === requestSequence) error.value = reason instanceof Error ? reason.message : 'Не удалось выполнить поиск сообщений.'
  } finally { if (sequence === requestSequence) loading.value = false }
}

function conversationLabel(message: SearchMessage): string {
  return message.kind === 'CHANNEL' ? props.channelLabels[message.channelId] ?? 'Текстовый канал' : props.directMessageLabels[message.directMessageId] ?? 'Личный диалог'
}
function formattedDate(value: string): string { return new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'long' }).format(new Date(value)) }
onBeforeUnmount(() => { requestSequence++ })
onMounted(() => { void nextTick(() => queryInput.value?.focus()) })
</script>

<template>
  <section class="search-panel" aria-labelledby="search-panel-title" data-testid="search-panel">
    <header class="search-panel-heading"><h1 id="search-panel-title">{{ activeView === 'messages' ? 'Поиск сообщений' : 'Упоминания' }}</h1><button class="search-close" type="button" aria-label="Закрыть поиск" @click="emit('close')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m18 6-12 12M6 6l12 12" /></svg></button></header>
    <div class="search-view-tabs" role="group" aria-label="Поиск и упоминания">
      <button id="search-messages-tab" type="button" :aria-pressed="activeView === 'messages'" aria-controls="search-messages-view" @click="activeView = 'messages'">Сообщения</button>
      <button id="search-mentions-tab" type="button" :aria-pressed="activeView === 'mentions'" aria-controls="search-mentions-view" @click="activeView = 'mentions'">Упоминания</button>
    </div>
    <div v-if="activeView === 'mentions'" id="search-mentions-view" role="region" aria-label="Упоминания">
      <PersonalMentionsPanel :channel-labels="channelLabels" :direct-message-labels="directMessageLabels" @open="emit('openMention', $event)" />
    </div>
    <div v-else id="search-messages-view" role="region" aria-label="Поиск сообщений">
    <form class="search-form" role="search" @submit.prevent="runSearch()">
      <label class="search-query-label"><span class="visually-hidden">Запрос</span><input ref="queryInput" v-model="query" type="search" autocomplete="off" placeholder="Поиск сообщений" :disabled="loading" :aria-describedby="error ? 'search-error' : undefined"></label>
      <div class="search-form-meta"><label class="search-scope-label"><span class="visually-hidden">Область поиска</span><select v-model="scope" :disabled="loading"><option value="all">Везде</option><option v-if="currentConversation" value="current">{{ currentConversation.label }}</option></select></label><span>Enter — найти</span></div>
      <SearchFilters v-model:author-id="filters.authorId" v-model:attachment="filters.attachment" v-model:date-from="filters.dateFrom" v-model:date-to="filters.dateTo" :disabled="loading" />
      <button class="search-submit" type="submit" :disabled="!canSubmit">{{ loading ? 'Ищем…' : 'Найти' }}</button>
    </form>
    <p v-if="error" id="search-error" class="search-error" role="alert">{{ error }}</p>
    <p class="search-status" :class="{ 'search-status--visible': loading || (!error && (!searched || !messages.length)) }" role="status" aria-live="polite" :aria-busy="loading">{{ loading ? 'Ищем сообщения…' : searched ? (messages.length ? `Найдено ${messages.length} сообщения` : 'Совпадений нет.') : 'Введите запрос и нажмите Enter.' }}</p>
    <span v-if="searched && messages.length" class="search-result-count" aria-hidden="true">Найдено {{ messages.length }} сообщения</span>
    <ol v-if="messages.length" class="search-results" aria-label="Результаты поиска">
      <li v-for="message in messages" :key="`${message.kind}:${message.id}`" class="search-result">
        <article><header>{{ conversationLabel(message) }} · <time :datetime="message.createdAt">{{ formattedDate(message.createdAt) }}</time></header><div class="search-result-author"><span class="search-result-avatar" :style="{ backgroundColor: avatarBackground(message.authorId), color: avatarForeground(message.authorId) }">{{ avatarInitials(authors.displayName(message.authorId)) }}</span><strong>{{ authors.displayName(message.authorId) }}</strong></div><SystemWelcomeMessage v-if="message.messageKind === 'SYSTEM_WELCOME'" :author-id="message.authorId" :body="message.body" /><SearchResultBody v-else :body="message.body" :query="activeQuery" /><button type="button" :aria-label="`Открыть сообщение от ${authors.displayName(message.authorId)}`" @click="emit('open', message)">Открыть сообщение</button></article>
      </li>
    </ol>
    <button v-if="nextCursor" class="search-more" type="button" :disabled="loading" @click="runSearch(nextCursor)">Показать ещё</button>
    </div>
  </section>
</template>

<style scoped>
.search-view-tabs { display: flex; gap: 8px; margin: 12px 20px; }
.search-view-tabs button { background: transparent; border: 1px solid var(--gc-border, #363a46); border-radius: 999px; color: inherit; cursor: pointer; min-height: 36px; padding: 6px 12px; }
.search-view-tabs button[aria-pressed="true"] { background: var(--gc-surface-raised, #20232d); border-color: var(--gc-accent, #6974f5); }
.search-view-tabs button:focus-visible { outline: 2px solid var(--gc-accent, #6974f5); outline-offset: 2px; }
</style>
