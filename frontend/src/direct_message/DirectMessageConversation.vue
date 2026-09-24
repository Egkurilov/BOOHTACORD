<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { loadCurrentSession, type CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import MentionPicker from '../conversation/MentionPicker.vue'
import DirectMessageHistoryList from './DirectMessageHistoryList.vue'
import DirectMessageSearch from './DirectMessageSearch.vue'
import type { DirectMessageHistoryItem } from './direct_message_client'
import { advanceReadIfVisible, newestServerMessageId } from './direct_message_read_gate'
import { useDirectMessageStore } from './direct_message_store'
import WorkspaceHeaderActions from '../workspace/WorkspaceHeaderActions.vue'

const props = defineProps<{ directMessageId: string; otherParticipantId: string; otherParticipantDisplayName: string; navOpen: boolean }>()
const emit = defineEmits<{ toggleNav: [] }>()
const store = useDirectMessageStore()
const authors = useAuthorDirectory()
const draft = ref('')
const session = ref<CurrentSession | null>(null)
const replyTarget = ref<DirectMessageHistoryItem | null>(null)
const mentionUserIds = ref<string[]>([])
const searchOpen = ref(false)
const emojiOpen = ref(false)
const emojis = ['😀', '👍', '🎮', '❤️', '🎉', '🤝']

async function markVisibleRead(): Promise<void> {
  try {
    const advanced = await advanceReadIfVisible({
      activeDirectMessageId: store.directMessageId,
      renderedDirectMessageId: props.directMessageId,
      newestDisplayedMessageId: newestServerMessageId(store.messages),
      visibilityState: document.visibilityState,
    })
    if (advanced) void store.refreshNavigation()
  } catch {
    return
  }
}

function queueVisibleRead(): void { void markVisibleRead() }

async function send(): Promise<void> {
  const target = store.directMessageId
  const body = draft.value
  const replyToId = replyTarget.value?.id
  const mentions = mentionUserIds.value.join(',')
  if (await store.send(body, undefined, undefined, replyToId, session.value?.accountId, mentionUserIds.value)
    && store.directMessageId === target && draft.value === body && replyTarget.value?.id === replyToId && mentionUserIds.value.join(',') === mentions) {
    draft.value = ''
    replyTarget.value = null
    mentionUserIds.value = []
  }
}

async function retry(message: DirectMessageHistoryItem): Promise<void> {
  if (await store.retry(message.clientMessageId) && store.directMessageId === message.directMessageId
    && draft.value === message.body && replyTarget.value?.id === message.replyToId && mentionUserIds.value.join(',') === message.mentionUserIds.join(',')) {
    draft.value = ''
    replyTarget.value = null
    mentionUserIds.value = []
  }
}

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}

function addEmoji(emoji: string): void { draft.value += emoji }

watch([() => props.directMessageId, () => store.directMessageId, () => store.messages], queueVisibleRead, { flush: 'post' })
watch(() => props.directMessageId, () => { mentionUserIds.value = [] })
onMounted(() => {
  document.addEventListener('visibilitychange', queueVisibleRead)
  void loadSession()
  queueVisibleRead()
})
onBeforeUnmount(() => document.removeEventListener('visibilitychange', queueVisibleRead))
</script>

<template>
  <section class="direct-message-conversation" aria-labelledby="direct-message-title">
    <header class="main-header conversation-header">
      <span class="conversation-symbol conversation-symbol--person" aria-hidden="true">@</span>
      <div class="main-title">
        <h2 id="direct-message-title">{{ props.otherParticipantDisplayName }}</h2>
        <small>Личный диалог</small>
      </div>
      <WorkspaceHeaderActions :members-expanded="false" :nav-expanded="props.navOpen" :show-members="false" @toggle-navigation="emit('toggleNav')"><button class="header-action" type="button" aria-label="Найти сообщение" :aria-expanded="searchOpen" @click="searchOpen = !searchOpen"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></svg></button></WorkspaceHeaderActions>
    </header>
    <div v-if="searchOpen" class="conversation-tools"><DirectMessageSearch :direct-message-id="props.directMessageId" /></div>
    <p v-if="store.loadingHistory" class="state" aria-live="polite">Загружаем историю…</p>
    <p v-if="store.error" class="state state-error" role="alert">{{ store.error }} <button v-if="!store.historyLoaded" type="button" @click="store.refreshHistory()">Повторить загрузку</button></p>
    <DirectMessageHistoryList :direct-message-id="props.directMessageId" :session="session" :other-participant-id="props.otherParticipantId" :other-participant-display-name="props.otherParticipantDisplayName" @reply="replyTarget = $event" @retry="retry" />
    <div class="composer-wrap">
      <form class="message-composer composer" @submit.prevent="send">
        <p v-if="replyTarget" class="reply-target">Ответ для {{ authors.displayName(replyTarget.authorId) }} <button type="button" @click="replyTarget = null">Отмена</button></p>
        <MentionPicker v-model="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" :only-participant="{ id: props.otherParticipantId, displayName: props.otherParticipantDisplayName }" />
        <label class="gc-sr-only" for="direct-message-body">Сообщение</label>
        <textarea id="direct-message-body" v-model="draft" maxlength="8000" :disabled="store.sending" placeholder="Написать сообщение…" />
        <span class="emoji-picker">
          <button class="emoji-trigger" type="button" aria-label="Добавить emoji" :aria-expanded="emojiOpen" @click="emojiOpen = !emojiOpen">☺</button>
          <span v-if="emojiOpen" class="emoji-menu" aria-label="Выбор emoji"><button v-for="emoji in emojis" :key="emoji" type="button" :aria-label="`Добавить ${emoji}`" @click="addEmoji(emoji); emojiOpen = false">{{ emoji }}</button></span>
        </span>
        <button class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || !draft"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m3 11 18-8-8 18-2-8-8-2Z" /><path d="m11 13 4-4" /></svg></button>
      </form>
    </div>
  </section>
</template>
