<script setup lang="ts">
import { computed, ref } from 'vue'

import type { TextMessage, TextMessageAttachment } from './message_client'
import MessageBody from './MessageBody.vue'
import TextMessageAttachments from './TextMessageAttachments.vue'

type RenderedMessage = Omit<TextMessage, 'channelId' | 'attachments'> & { channelId?: string; attachments?: TextMessageAttachment[] }

const props = defineProps<{ message: RenderedMessage; replyPreview?: string; canEdit: boolean; canDelete: boolean; retryDisabled?: boolean }>()
const emit = defineEmits<{ edit: [body: string]; remove: []; reply: []; retry: [] }>()
const editing = ref(false)
const body = ref('')
const textChannelId = computed(() => props.message.channelId ?? '')
const textAttachments = computed(() => props.message.attachments ?? [])

function beginEdit(): void {
  body.value = props.message.body
  editing.value = true
}

function saveEdit(): void {
  if (!body.value) return
  emit('edit', body.value)
  editing.value = false
}

function remove(): void {
  if (window.confirm('Удалить это сообщение?')) emit('remove')
}

function initial(authorId: string): string {
  return authorId.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У'
}
</script>

<template>
  <article class="message-item message-row" :class="{ deleted: message.deleted }">
    <span class="message-avatar" aria-hidden="true">{{ initial(message.authorId) }}</span>
    <div class="message-content">
      <div class="message-meta">
        <span class="message-author">{{ message.authorId }}</span>
        <time class="message-time">{{ new Date(message.createdAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) }}</time>
        <span v-if="message.editedAt" class="message-time">изменено</span>
      </div>
      <p v-if="message.deleted">Сообщение удалено</p>
      <template v-else-if="editing">
        <textarea v-model="body" maxlength="8000" aria-label="Изменённый текст сообщения" />
        <button type="button" @click="saveEdit">Сохранить</button>
        <button type="button" @click="editing = false">Отмена</button>
      </template>
      <template v-else>
        <p v-if="replyPreview" class="reply-preview">↪ {{ replyPreview }}</p>
        <MessageBody :body="message.body" />
        <TextMessageAttachments v-if="textChannelId && textAttachments.length" :channel-id="textChannelId" :attachments="textAttachments" />
        <p v-if="message.sendStatus === 'sending'" class="message-send-status" role="status">Отправляется…</p>
        <div v-if="message.sendStatus === 'failed'" class="message-send-status" role="alert"><span>Не отправлено</span><button type="button" :disabled="retryDisabled" @click="emit('retry')">Повторить отправку</button></div>
      </template>
      <p v-if="!message.deleted && !message.sendStatus" class="message-actions">
        <button type="button" @click="emit('reply')">Ответить</button>
        <button v-if="canEdit" type="button" @click="beginEdit">Изменить</button>
        <button v-if="canDelete" type="button" @click="remove">Удалить</button>
      </p>
    </div>
  </article>
</template>
