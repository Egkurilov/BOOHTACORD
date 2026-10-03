<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { useTopologyStore } from '../channel/topology_store'
import { loadCurrentSession, type CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import type { TextMessage } from './message_client'
import { useMessageStore } from './message_store'
import TextHistoryList from './TextHistoryList.vue'
import TextMessageAttachmentPicker from './TextMessageAttachmentPicker.vue'
import TextMessageSearch from './TextMessageSearch.vue'
import MentionPicker from './MentionPicker.vue'
import MentionAutocomplete from './MentionAutocomplete.vue'
import ConversationOverflowMenu from './ConversationOverflowMenu.vue'
import type { TextAttachmentUpload } from './text_attachment_upload_client'
import { advanceTextReadIfVisible } from './text_read_gate'
import WorkspaceHeaderActions from '../shared/workspace_header/WorkspaceHeaderActions.vue'
import { useSavedComposer } from './use_saved_composer'
import { submitOnComposerEnter } from './composer_enter'
import SearchMessageContext from '../search/SearchMessageContext.vue'
import { useSearchTargetStore } from '../search/search_target_store'
import { pasteClipboardImages } from './clipboard_images'
import { useUnreadBoundary } from './use_unread_boundary'
import { useScopedSend } from './use_scoped_send'
import { useVisibleRead } from './use_visible_read'

const props = defineProps<{ accountId: string; active: boolean; channelId: string; channelName: string; navOpen: boolean; membersOpen: boolean; showMembers: boolean }>()
const emit = defineEmits<{ toggleNav: []; toggleMembers: [] }>()
const store = useMessageStore()
const topology = useTopologyStore()
const searchTarget = useSearchTargetStore()
const contextTarget = computed(() => searchTarget.target?.kind === 'CHANNEL' && searchTarget.target.conversationId === props.channelId ? searchTarget.target : null)
const replyContextTarget = ref<string | null>(null)
const firstUnread = computed(() => topology.topology?.categories.flatMap(({ channels }) => channels).find(({ id }) => id === props.channelId)?.firstUnreadMessageId)
const { unreadBoundary, unreadContextOpen, readUnlocked, showUnread, continueAtLatest } = useUnreadBoundary(() => props.channelId, firstUnread, () => queueVisibleRead())
const authors = useAuthorDirectory()
const session = ref<CurrentSession | null>(null)
const composer = useSavedComposer<TextMessage, TextAttachmentUpload>(props.accountId, 'CHANNEL', () => props.channelId)
const { draft, replyTarget, attachments, mentionUserIds, attachmentPending, attachmentClearToken } = composer
const searchOpen = ref(false)
const searchTrigger = ref<HTMLButtonElement | null>(null)
const composerTextarea = ref<HTMLTextAreaElement | null>(null)
const attachmentPicker = ref<{ addPastedFiles: (files: File[]) => void } | null>(null)
const emojiOpen = ref(false)
const emojis = ['😀', '👍', '🎮', '❤️', '🎉', '🤝']
const { readRoot, queueVisibleRead } = useVisibleRead({
  conversationId: () => props.channelId, loadedConversationId: () => store.channelId, messages: () => store.messages,
  canRead: () => props.active && Boolean(topology.topology) && (!unreadBoundary.value || readUnlocked.value),
  advance: (id, messageId) => advanceTextReadIfVisible({ activeChannelId: store.channelId, renderedChannelId: id,
    newestDisplayedMessageId: messageId, visibilityState: document.visibilityState }),
  refreshCounters: () => { void topology.refresh() },
})
watch(() => props.channelId, (channelId) => {
  replyContextTarget.value = null
  void store.open(channelId)
  void loadSession()
}, { immediate: true })
onBeforeUnmount(() => searchTarget.clearFor('CHANNEL', props.channelId))

const { send, retry } = useScopedSend<TextMessage, TextAttachmentUpload, TextMessage>(
  props.accountId, 'CHANNEL', () => props.channelId, composer,
  () => !attachmentPending.value && store.channelId === props.channelId,
  () => store.send(draft.value, undefined, undefined, replyTarget.value?.id, attachments.value, session.value?.accountId, mentionUserIds.value),
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
</script>

<template>
  <section ref="readRoot" class="text-conversation" aria-labelledby="conversation-title">
    <header class="main-header conversation-header">
      <span class="conversation-symbol" aria-hidden="true">#</span>
      <div class="main-title">
        <h2 id="conversation-title">{{ channelName }}</h2>
      </div>
      <WorkspaceHeaderActions :members-expanded="props.membersOpen" :nav-expanded="props.navOpen" :show-members="props.showMembers" @toggle-members="emit('toggleMembers')" @toggle-navigation="emit('toggleNav')"><button ref="searchTrigger" class="header-action" type="button" aria-label="Найти сообщение" :aria-expanded="searchOpen" @click="searchOpen ? closeSearch() : searchOpen = true"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></svg></button><template #overflow><ConversationOverflowMenu :show-members="props.showMembers" :members-open="props.membersOpen" @search="searchOpen = true" @toggle-members="emit('toggleMembers')" /></template></WorkspaceHeaderActions>
    </header>
    <div v-if="searchOpen" class="conversation-tools"><TextMessageSearch :channel-id="props.channelId" @close="closeSearch" /></div>
    <p v-if="store.loading" class="state" aria-live="polite">Загружаем историю…</p>
    <p v-if="store.error" id="text-conversation-error" class="state state-error" role="alert">{{ store.error }} <button v-if="!store.historyLoaded" type="button" @click="store.refresh()">Повторить загрузку</button></p>
    <div v-if="unreadBoundary && !readUnlocked" class="unread-boundary-actions" role="status">
      <span>Есть непрочитанные сообщения.</span>
      <button type="button" @click="showUnread">К первому непрочитанному</button>
      <button type="button" @click="continueAtLatest">Остаться у последних</button>
    </div>
    <SearchMessageContext v-if="contextTarget" kind="CHANNEL" :conversation-id="props.channelId" :message-id="contextTarget.messageId" @close="searchTarget.clear()" />
    <SearchMessageContext v-else-if="replyContextTarget" kind="CHANNEL" :conversation-id="props.channelId" :message-id="replyContextTarget" heading="Контекст ответа" @close="replyContextTarget = null" />
    <SearchMessageContext v-else-if="unreadContextOpen" kind="CHANNEL" :conversation-id="props.channelId" :message-id="unreadBoundary" heading="Первое непрочитанное сообщение" @close="continueAtLatest" />
    <TextHistoryList :channel-id="props.channelId" :session="session" @reply="replyTarget = $event" @reply-context="replyContextTarget = $event" @retry="retry" @viewport-change="queueVisibleRead" />
    <div class="composer-wrap">
      <p v-if="replyTarget" class="reply-target">Ответ для {{ authors.displayName(replyTarget.authorId) }} <button type="button" @click="replyTarget = null">Отмена</button></p>
      <MentionAutocomplete v-model="draft" v-model:mention-user-ids="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" />
      <form class="message-composer composer" @submit.prevent="send">
        <TextMessageAttachmentPicker ref="attachmentPicker" :channel-id="props.channelId" :initial-attachments="attachments" :disabled="store.sending || attachmentPending"
          :clear-token="attachmentClearToken" @change="attachments = $event" @pending="attachmentPending = $event" />
        <MentionPicker v-model="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" />
        <label class="gc-sr-only" for="message-body">Сообщение</label>
        <textarea id="message-body" ref="composerTextarea" v-model="draft" rows="1" :disabled="store.sending" :aria-describedby="store.error ? 'text-conversation-error text-composer-help' : 'text-composer-help'" placeholder="Написать сообщение…" @keydown="submitOnComposerEnter($event, send)" @paste="onComposerPaste" />
        <span class="emoji-picker">
          <button class="emoji-trigger" type="button" aria-label="Добавить emoji" :aria-expanded="emojiOpen" @click="emojiOpen = !emojiOpen">☺</button>
          <span v-if="emojiOpen" class="emoji-menu" aria-label="Выбор emoji"><button v-for="emoji in emojis" :key="emoji" type="button" :aria-label="`Добавить ${emoji}`" @click="addEmoji(emoji); emojiOpen = false">{{ emoji }}</button></span>
        </span>
        <button class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || attachmentPending || (!draft && attachments.length === 0)"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m3 11 18-8-8 18-2-8-8-2Z" /><path d="m11 13 4-4" /></svg></button>
      </form>
      <div class="composer-helper"><p id="text-composer-help">Enter — отправить · Shift+Enter — новая строка</p><p class="composer-helper__limit">До 25 МБ на файл</p></div>
    </div>
  </section>
</template>
