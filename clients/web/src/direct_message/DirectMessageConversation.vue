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
import { useDirectMessageStore } from './direct_message_store'
import WorkspaceHeaderActions from '../shared/workspace_header/WorkspaceHeaderActions.vue'
import { useSavedComposer } from '../conversation/use_saved_composer'
import { submitOnComposerEnter } from '../conversation/composer_enter'
import SearchMessageContext from '../search/SearchMessageContext.vue'
import { useSearchTargetStore } from '../search/search_target_store'
import { pasteClipboardImages } from '../conversation/clipboard_images'
import { useUnreadBoundary } from '../conversation/use_unread_boundary'
import { useScopedSend } from '../conversation/use_scoped_send'
import { useVisibleRead } from '../conversation/use_visible_read'
const props = defineProps<{ accountId: string; active: boolean; directMessageId: string; otherParticipantId: string; otherParticipantDisplayName: string; navOpen: boolean }>()
const emit = defineEmits<{ toggleNav: [] }>()
const store = useDirectMessageStore()
const firstUnread = computed(() => store.directMessages.find(({ id }) => id === props.directMessageId)?.firstUnreadMessageId)
const { unreadBoundary, unreadContextOpen, readUnlocked, showUnread, continueAtLatest } = useUnreadBoundary(() => props.directMessageId, firstUnread, () => queueVisibleRead())
const searchTarget = useSearchTargetStore()
const contextTarget = computed(() => searchTarget.target?.kind === 'DIRECT_MESSAGE' && searchTarget.target.conversationId === props.directMessageId ? searchTarget.target : null)
const replyContextTarget = ref<string | null>(null)
const authors = useAuthorDirectory()
const session = ref<CurrentSession | null>(null)
const composer = useSavedComposer<DirectMessageHistoryItem, TextMessageAttachment>(props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId)
const { draft, replyTarget, mentionUserIds, attachments, attachmentPending, attachmentClearToken } = composer
const searchOpen = ref(false)
const searchTrigger = ref<HTMLButtonElement | null>(null)
const composerTextarea = ref<HTMLTextAreaElement | null>(null)
const attachmentPicker = ref<{ addPastedFiles: (files: File[]) => void } | null>(null)
const emojiOpen = ref(false)
const emojis = ['😀', '👍', '🎮', '❤️', '🎉', '🤝']
const { readRoot, queueVisibleRead } = useVisibleRead({
  conversationId: () => props.directMessageId, loadedConversationId: () => store.directMessageId, messages: () => store.messages,
  canRead: () => props.active && store.directMessages.some(({ id }) => id === props.directMessageId) && (!unreadBoundary.value || readUnlocked.value),
  advance: (id, messageId) => advanceReadIfVisible({ activeDirectMessageId: store.directMessageId,
    renderedDirectMessageId: id, newestDisplayedMessageId: messageId, visibilityState: document.visibilityState }),
  refreshCounters: () => { void store.refreshNavigation() },
})

const { send, retry } = useScopedSend<DirectMessageHistoryItem, TextMessageAttachment, DirectMessageHistoryItem>(
  props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId, composer,
  () => !attachmentPending.value && store.directMessageId === props.directMessageId,
  () => store.send(draft.value, undefined, undefined, replyTarget.value?.id, session.value?.accountId, mentionUserIds.value, attachments.value),
  (id) => store.retry(id),
)

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}

function addEmoji(emoji: string): void { draft.value += emoji }
function closeSearch(): void { searchOpen.value = false; void nextTick(() => searchTrigger.value?.focus()) }
function onComposerPaste(event: ClipboardEvent): void {
  if (composerTextarea.value) pasteClipboardImages(event, composerTextarea.value, (files) => attachmentPicker.value?.addPastedFiles(files))
}

onMounted(() => {
  void loadSession()
})
watch(() => props.directMessageId, () => { replyContextTarget.value = null })
onBeforeUnmount(() => searchTarget.clearFor('DIRECT_MESSAGE', props.directMessageId))
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
    <div v-if="unreadBoundary && !readUnlocked" class="unread-boundary-actions" role="status">
      <span>Есть непрочитанные сообщения.</span>
      <button type="button" @click="showUnread">К первому непрочитанному</button>
      <button type="button" @click="continueAtLatest">Остаться у последних</button>
    </div>
    <SearchMessageContext v-if="contextTarget" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="contextTarget.messageId" @close="searchTarget.clear()" />
    <SearchMessageContext v-else-if="replyContextTarget" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="replyContextTarget" heading="Контекст ответа" @close="replyContextTarget = null" />
    <SearchMessageContext v-else-if="unreadContextOpen" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="unreadBoundary" heading="Первое непрочитанное сообщение" @close="continueAtLatest" />
    <DirectMessageHistoryList :direct-message-id="props.directMessageId" :session="session" :other-participant-id="props.otherParticipantId" :other-participant-display-name="props.otherParticipantDisplayName" @reply="replyTarget = $event" @reply-context="replyContextTarget = $event" @retry="retry" @viewport-change="queueVisibleRead" />
    <div class="composer-wrap">
      <form class="message-composer composer" @submit.prevent="send">
        <p v-if="replyTarget" class="reply-target">Ответ для {{ authors.displayName(replyTarget.authorId) }} <button type="button" @click="replyTarget = null">Отмена</button></p>
        <DirectMessageAttachmentPicker ref="attachmentPicker" :direct-message-id="props.directMessageId" :initial-attachments="attachments" :disabled="store.sending || attachmentPending" :clear-token="attachmentClearToken" @change="attachments = $event" @pending="attachmentPending = $event" />
        <MentionPicker v-model="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" :only-participant="{ id: props.otherParticipantId, displayName: props.otherParticipantDisplayName }" />
        <label class="gc-sr-only" for="direct-message-body">Сообщение</label>
        <textarea id="direct-message-body" ref="composerTextarea" v-model="draft" rows="1" :disabled="store.sending" :aria-describedby="store.error ? 'direct-conversation-error direct-composer-help' : 'direct-composer-help'" placeholder="Написать сообщение…" @keydown="submitOnComposerEnter($event, send)" @paste="onComposerPaste" />
        <span class="emoji-picker">
          <button class="emoji-trigger" type="button" aria-label="Добавить emoji" :aria-expanded="emojiOpen" @click="emojiOpen = !emojiOpen">☺</button>
          <span v-if="emojiOpen" class="emoji-menu" aria-label="Выбор emoji"><button v-for="emoji in emojis" :key="emoji" type="button" :aria-label="`Добавить ${emoji}`" @click="addEmoji(emoji); emojiOpen = false">{{ emoji }}</button></span>
        </span>
        <button class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || attachmentPending || (!draft && attachments.length === 0)"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m3 11 18-8-8 18-2-8-8-2Z" /><path d="m11 13 4-4" /></svg></button>
      </form>
      <div class="composer-helper"><p id="direct-composer-help">Enter — отправить · Shift+Enter — новая строка</p><p class="composer-helper__limit">До 25 МБ на файл</p></div>
    </div>
  </section>
</template>
