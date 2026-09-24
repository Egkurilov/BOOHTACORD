<script setup lang="ts">
import { ref, watch } from 'vue'
import { loadCurrentSession, type CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import type { TextMessage } from './message_client'
import { useMessageStore } from './message_store'
import TextHistoryList from './TextHistoryList.vue'
import TextMessageAttachmentPicker from './TextMessageAttachmentPicker.vue'
import TextMessageSearch from './TextMessageSearch.vue'
import type { TextAttachmentUpload } from './text_attachment_upload_client'
import WorkspaceHeaderActions from '../workspace/WorkspaceHeaderActions.vue'

const props = defineProps<{ channelId: string; channelName: string; navOpen: boolean; membersOpen: boolean; showMembers: boolean }>()
const emit = defineEmits<{ toggleNav: []; toggleMembers: [] }>()
const store = useMessageStore()
const authors = useAuthorDirectory()
const draft = ref('')
const session = ref<CurrentSession | null>(null)
const replyTarget = ref<TextMessage | null>(null)
const attachments = ref<TextAttachmentUpload[]>([])
const attachmentPending = ref(false)
const attachmentClearToken = ref(0)
const searchOpen = ref(false)
const emojiOpen = ref(false)
const emojis = ['😀', '👍', '🎮', '❤️', '🎉', '🤝']

watch(() => props.channelId, (channelId) => {
  attachments.value = []
  void store.open(channelId)
  void loadSession()
}, { immediate: true })

async function send(): Promise<void> {
  if (await store.send(draft.value, undefined, undefined, replyTarget.value?.id, attachments.value, session.value?.accountId)) clearComposer()
}

async function retry(message: TextMessage): Promise<void> {
  if (!await store.retry(message.clientMessageId)) return
  const sameAttachments = attachments.value.map(({ id }) => id).join(',') === message.attachments.map(({ id }) => id).join(',')
  if (draft.value === message.body && replyTarget.value?.id === message.replyToId && sameAttachments) clearComposer()
}

function clearComposer(): void {
  draft.value = ''
  replyTarget.value = null
  attachmentClearToken.value += 1
}

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}

function addEmoji(emoji: string): void {
  draft.value += emoji
}
</script>

<template>
  <section class="text-conversation" aria-labelledby="conversation-title">
    <header class="main-header conversation-header">
      <span class="conversation-symbol" aria-hidden="true">#</span>
      <div class="main-title">
        <h2 id="conversation-title">{{ channelName }}</h2>
      </div>
      <WorkspaceHeaderActions :members-expanded="props.membersOpen" :nav-expanded="props.navOpen" :show-members="props.showMembers" @toggle-members="emit('toggleMembers')" @toggle-navigation="emit('toggleNav')"><button class="header-action" type="button" aria-label="Найти сообщение" :aria-expanded="searchOpen" @click="searchOpen = !searchOpen"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></svg></button></WorkspaceHeaderActions>
    </header>
    <div v-if="searchOpen" class="conversation-tools"><TextMessageSearch :channel-id="props.channelId" /></div>
    <p v-if="store.loading" class="state" aria-live="polite">Загружаем историю…</p>
    <p v-if="store.error" class="state state-error" role="alert">{{ store.error }} <button v-if="!store.historyLoaded" type="button" @click="store.refresh()">Повторить загрузку</button></p>
    <TextHistoryList :channel-id="props.channelId" :session="session" @reply="replyTarget = $event" @retry="retry" />
    <div class="composer-wrap">
      <form class="message-composer composer" @submit.prevent="send">
        <p v-if="replyTarget" class="reply-target">Ответ для {{ authors.displayName(replyTarget.authorId) }} <button type="button" @click="replyTarget = null">Отмена</button></p>
        <TextMessageAttachmentPicker
          :channel-id="props.channelId"
          :disabled="store.sending || attachmentPending"
          :clear-token="attachmentClearToken"
          @change="attachments = $event"
          @pending="attachmentPending = $event"
        />
        <label class="gc-sr-only" for="message-body">Сообщение</label>
        <textarea id="message-body" v-model="draft" maxlength="8000" :disabled="store.sending" placeholder="Написать сообщение…" />
        <span class="emoji-picker">
          <button class="emoji-trigger" type="button" aria-label="Добавить emoji" :aria-expanded="emojiOpen" @click="emojiOpen = !emojiOpen">☺</button>
          <span v-if="emojiOpen" class="emoji-menu" aria-label="Выбор emoji"><button v-for="emoji in emojis" :key="emoji" type="button" :aria-label="`Добавить ${emoji}`" @click="addEmoji(emoji); emojiOpen = false">{{ emoji }}</button></span>
        </span>
        <button class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || attachmentPending || !draft"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m3 11 18-8-8 18-2-8-8-2Z" /><path d="m11 13 4-4" /></svg></button>
      </form>
    </div>
  </section>
</template>
