<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useTopologyStore } from '../channel/topology_store'
import { loadCurrentSession, type CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import type { TextMessage } from './message_client'
import { useMessageStore } from './message_store'
import TextHistoryList from './TextHistoryList.vue'
import TextMessageAttachmentPicker from './TextMessageAttachmentPicker.vue'
import TextMessageSearch from './TextMessageSearch.vue'
import MentionPicker from './MentionPicker.vue'
import ConversationOverflowMenu from './ConversationOverflowMenu.vue'
import type { TextAttachmentUpload } from './text_attachment_upload_client'
import { advanceTextReadIfVisible } from './text_read_gate'
import { newestVisibleServerMessageId, shouldAdvanceVisibleRead } from './read_visibility'
import WorkspaceHeaderActions from '../workspace/WorkspaceHeaderActions.vue'
import { useComposerScope } from './composer_scope'
import { submitOnComposerEnter } from './composer_enter'
import SearchMessageContext from '../search/SearchMessageContext.vue'
import { useSearchTargetStore } from '../search/search_target_store'

const props = defineProps<{ channelId: string; channelName: string; navOpen: boolean; membersOpen: boolean; showMembers: boolean }>()
const emit = defineEmits<{ toggleNav: []; toggleMembers: [] }>()
const store = useMessageStore()
const topology = useTopologyStore()
const searchTarget = useSearchTargetStore()
const contextTarget = computed(() => searchTarget.target?.kind === 'CHANNEL' && searchTarget.target.conversationId === props.channelId ? searchTarget.target : null)
const authors = useAuthorDirectory()
const session = ref<CurrentSession | null>(null)
const composer = useComposerScope<TextMessage, TextAttachmentUpload>()
const { draft, replyTarget, attachments, mentionUserIds, attachmentPending, attachmentClearToken } = composer
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
  const key = `${props.channelId}:${messageId}`
  if (!shouldAdvanceVisibleRead(store.messages, lastReadKey, props.channelId, messageId) || readPending.has(key)) return
  readPending.add(key)
  try {
    const advanced = await advanceTextReadIfVisible({ activeChannelId: store.channelId, renderedChannelId: props.channelId,
      newestDisplayedMessageId: messageId, visibilityState: document.visibilityState })
    if (advanced) { if (shouldAdvanceVisibleRead(store.messages, lastReadKey, props.channelId, messageId)) lastReadKey = key; void topology.refresh() }
  } catch { /* Keep counters until a later visible retry. */ }
  finally { readPending.delete(key) }
}

function queueVisibleRead(): void { void markVisibleRead() }
watch(() => props.channelId, (channelId) => {
  composer.reset()
  lastReadKey = ''
  void store.open(channelId)
  void loadSession()
}, { immediate: true })
watch([() => props.channelId, () => store.channelId, () => store.messages], queueVisibleRead, { flush: 'post' })
onMounted(() => { document.addEventListener('visibilitychange', queueVisibleRead); window.addEventListener('resize', queueVisibleRead); queueVisibleRead() })
onBeforeUnmount(() => { document.removeEventListener('visibilitychange', queueVisibleRead); window.removeEventListener('resize', queueVisibleRead); searchTarget.clearFor('CHANNEL', props.channelId) })

async function send(): Promise<void> {
  if (attachmentPending.value || store.channelId !== props.channelId) return
  const saved = composer.snapshot(props.channelId)
  if (await store.send(draft.value, undefined, undefined, replyTarget.value?.id, attachments.value, session.value?.accountId, mentionUserIds.value)
    && composer.unchanged(saved, props.channelId) && store.channelId === props.channelId) composer.clear()
}

async function retry(message: TextMessage): Promise<void> {
  const saved = composer.snapshot(props.channelId)
  if (await store.retry(message.clientMessageId) && composer.unchanged(saved, props.channelId)
    && store.channelId === props.channelId && composer.matchesMessage(message)) composer.clear()
}

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}

function addEmoji(emoji: string): void { draft.value += emoji }
function closeSearch(): void { searchOpen.value = false; void nextTick(() => searchTrigger.value?.focus()) }
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
    <SearchMessageContext v-if="contextTarget" kind="CHANNEL" :conversation-id="props.channelId" :message-id="contextTarget.messageId" @close="searchTarget.clear()" />
    <TextHistoryList :channel-id="props.channelId" :session="session" @reply="replyTarget = $event" @retry="retry" @viewport-change="queueVisibleRead" />
    <div class="composer-wrap">
      <form class="message-composer composer" @submit.prevent="send">
        <p v-if="replyTarget" class="reply-target">Ответ для {{ authors.displayName(replyTarget.authorId) }} <button type="button" @click="replyTarget = null">Отмена</button></p>
        <TextMessageAttachmentPicker :channel-id="props.channelId" :disabled="store.sending || attachmentPending"
          :clear-token="attachmentClearToken" @change="attachments = $event" @pending="attachmentPending = $event" />
        <MentionPicker v-model="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" />
        <label class="gc-sr-only" for="message-body">Сообщение</label>
        <textarea id="message-body" v-model="draft" rows="1" :disabled="store.sending" :aria-describedby="store.error ? 'text-conversation-error text-composer-help' : 'text-composer-help'" placeholder="Написать сообщение…" @keydown="submitOnComposerEnter($event, send)" />
        <span class="emoji-picker">
          <button class="emoji-trigger" type="button" aria-label="Добавить emoji" :aria-expanded="emojiOpen" @click="emojiOpen = !emojiOpen">☺</button>
          <span v-if="emojiOpen" class="emoji-menu" aria-label="Выбор emoji"><button v-for="emoji in emojis" :key="emoji" type="button" :aria-label="`Добавить ${emoji}`" @click="addEmoji(emoji); emojiOpen = false">{{ emoji }}</button></span>
        </span>
        <button class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || attachmentPending || !draft"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m3 11 18-8-8 18-2-8-8-2Z" /><path d="m11 13 4-4" /></svg></button>
      </form>
      <div class="composer-helper"><p id="text-composer-help">Enter — отправить · Shift+Enter — новая строка</p><p class="composer-helper__limit">До 25 МБ на файл</p></div>
    </div>
  </section>
</template>
