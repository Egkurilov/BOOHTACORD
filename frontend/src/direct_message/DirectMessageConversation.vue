<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { loadCurrentSession, type CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import MentionPicker from '../conversation/MentionPicker.vue'
import ConversationOverflowMenu from '../conversation/ConversationOverflowMenu.vue'
import type { TextMessageAttachment } from '../conversation/message_client'
import DirectMessageAttachmentPicker from './DirectMessageAttachmentPicker.vue'
import DirectMessageHistoryList from './DirectMessageHistoryList.vue'
import DirectMessageSearch from './DirectMessageSearch.vue'
import type { DirectMessageHistoryItem } from './direct_message_client'
import { advanceReadIfVisible } from './direct_message_read_gate'
import { newestVisibleServerMessageId, shouldAdvanceVisibleRead } from '../conversation/read_visibility'
import { useDirectMessageStore } from './direct_message_store'
import WorkspaceHeaderActions from '../workspace/WorkspaceHeaderActions.vue'
import { useComposerScope } from '../conversation/composer_scope'
import { submitOnComposerEnter } from '../conversation/composer_enter'
import SearchMessageContext from '../search/SearchMessageContext.vue'
import { useSearchTargetStore } from '../search/search_target_store'
const props = defineProps<{ directMessageId: string; otherParticipantId: string; otherParticipantDisplayName: string; navOpen: boolean }>()
const emit = defineEmits<{ toggleNav: [] }>()
const store = useDirectMessageStore()
const searchTarget = useSearchTargetStore()
const contextTarget = computed(() => searchTarget.target?.kind === 'DIRECT_MESSAGE' && searchTarget.target.conversationId === props.directMessageId ? searchTarget.target : null)
const authors = useAuthorDirectory()
const session = ref<CurrentSession | null>(null)
const composer = useComposerScope<DirectMessageHistoryItem, TextMessageAttachment>()
const { draft, replyTarget, mentionUserIds, attachments, attachmentPending, attachmentClearToken } = composer
const searchOpen = ref(false)
const searchTrigger = ref<HTMLButtonElement | null>(null)
const readRoot = ref<HTMLElement | null>(null)
const emojiOpen = ref(false)
const emojis = ['😀', '👍', '🎮', '❤️', '🎉', '🤝']
const readPending = new Set<string>()
let lastReadKey = ''

async function markVisibleRead(): Promise<void> {
  const messageId = newestVisibleServerMessageId(readRoot.value?.querySelector<HTMLElement>('.message-list') ?? null, store.messages)
  if (!messageId) return
  const key = `${props.directMessageId}:${messageId}`
  if (!shouldAdvanceVisibleRead(store.messages, lastReadKey, props.directMessageId, messageId) || readPending.has(key)) return
  readPending.add(key)
  try {
    const advanced = await advanceReadIfVisible({
      activeDirectMessageId: store.directMessageId,
      renderedDirectMessageId: props.directMessageId,
      newestDisplayedMessageId: messageId,
      visibilityState: document.visibilityState,
    })
    if (advanced) { if (shouldAdvanceVisibleRead(store.messages, lastReadKey, props.directMessageId, messageId)) lastReadKey = key; void store.refreshNavigation() }
  } catch {
    return
  } finally { readPending.delete(key) }
}
function queueVisibleRead(): void { void markVisibleRead() }

async function send(): Promise<void> {
  if (attachmentPending.value || store.directMessageId !== props.directMessageId) return
  const target = store.directMessageId
  const saved = composer.snapshot(target)
  if (await store.send(draft.value, undefined, undefined, replyTarget.value?.id, session.value?.accountId, mentionUserIds.value, attachments.value)
    && composer.unchanged(saved, props.directMessageId) && store.directMessageId === target) composer.clear()
}

async function retry(message: DirectMessageHistoryItem): Promise<void> {
  const saved = composer.snapshot(props.directMessageId)
  if (await store.retry(message.clientMessageId) && store.directMessageId === message.directMessageId
    && composer.unchanged(saved, props.directMessageId) && composer.matchesMessage(message)) composer.clear()
}

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}

function addEmoji(emoji: string): void { draft.value += emoji }
function closeSearch(): void { searchOpen.value = false; void nextTick(() => searchTrigger.value?.focus()) }

watch([() => props.directMessageId, () => store.directMessageId, () => store.messages], queueVisibleRead, { flush: 'post' })
watch(() => props.directMessageId, () => { composer.reset(); lastReadKey = '' })
onMounted(() => {
  document.addEventListener('visibilitychange', queueVisibleRead)
  window.addEventListener('resize', queueVisibleRead)
  void loadSession()
  queueVisibleRead()
})
onBeforeUnmount(() => { document.removeEventListener('visibilitychange', queueVisibleRead); window.removeEventListener('resize', queueVisibleRead); searchTarget.clearFor('DIRECT_MESSAGE', props.directMessageId) })
</script>

<template>
  <section ref="readRoot" class="direct-message-conversation" aria-labelledby="direct-message-title">
    <header class="main-header conversation-header">
      <span class="conversation-symbol conversation-symbol--person" aria-hidden="true">@</span>
      <div class="main-title">
        <h2 id="direct-message-title">{{ props.otherParticipantDisplayName }}</h2>
        <small>Личный диалог</small>
      </div>
      <WorkspaceHeaderActions :members-expanded="false" :nav-expanded="props.navOpen" :show-members="false" @toggle-navigation="emit('toggleNav')"><button ref="searchTrigger" class="header-action" type="button" aria-label="Найти сообщение" :aria-expanded="searchOpen" @click="searchOpen ? closeSearch() : searchOpen = true"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></svg></button><template #overflow><ConversationOverflowMenu @search="searchOpen = true" /></template></WorkspaceHeaderActions>
    </header>
    <div v-if="searchOpen" class="conversation-tools"><DirectMessageSearch :direct-message-id="props.directMessageId" @close="closeSearch" /></div>
    <p v-if="store.loadingHistory" class="state" aria-live="polite">Загружаем историю…</p>
    <p v-if="store.error" id="direct-conversation-error" class="state state-error" role="alert">{{ store.error }} <button v-if="!store.historyLoaded" type="button" @click="store.refreshHistory()">Повторить загрузку</button></p>
    <SearchMessageContext v-if="contextTarget" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="contextTarget.messageId" @close="searchTarget.clear()" />
    <DirectMessageHistoryList :direct-message-id="props.directMessageId" :session="session" :other-participant-id="props.otherParticipantId" :other-participant-display-name="props.otherParticipantDisplayName" @reply="replyTarget = $event" @retry="retry" @viewport-change="queueVisibleRead" />
    <div class="composer-wrap">
      <form class="message-composer composer" @submit.prevent="send">
        <p v-if="replyTarget" class="reply-target">Ответ для {{ authors.displayName(replyTarget.authorId) }} <button type="button" @click="replyTarget = null">Отмена</button></p>
        <DirectMessageAttachmentPicker :direct-message-id="props.directMessageId" :disabled="store.sending || attachmentPending" :clear-token="attachmentClearToken" @change="attachments = $event" @pending="attachmentPending = $event" />
        <MentionPicker v-model="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" :only-participant="{ id: props.otherParticipantId, displayName: props.otherParticipantDisplayName }" />
        <label class="gc-sr-only" for="direct-message-body">Сообщение</label>
        <textarea id="direct-message-body" v-model="draft" rows="1" :disabled="store.sending" :aria-describedby="store.error ? 'direct-conversation-error direct-composer-help' : 'direct-composer-help'" placeholder="Написать сообщение…" @keydown="submitOnComposerEnter($event, send)" />
        <span class="emoji-picker">
          <button class="emoji-trigger" type="button" aria-label="Добавить emoji" :aria-expanded="emojiOpen" @click="emojiOpen = !emojiOpen">☺</button>
          <span v-if="emojiOpen" class="emoji-menu" aria-label="Выбор emoji"><button v-for="emoji in emojis" :key="emoji" type="button" :aria-label="`Добавить ${emoji}`" @click="addEmoji(emoji); emojiOpen = false">{{ emoji }}</button></span>
        </span>
        <button class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || attachmentPending || !draft"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m3 11 18-8-8 18-2-8-8-2Z" /><path d="m11 13 4-4" /></svg></button>
      </form>
      <div class="composer-helper"><p id="direct-composer-help">Enter — отправить · Shift+Enter — новая строка</p><p class="composer-helper__limit">До 25 МБ на файл</p></div>
    </div>
  </section>
</template>
