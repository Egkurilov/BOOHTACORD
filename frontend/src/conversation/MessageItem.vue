<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import type { TextMessage, TextMessageAttachment } from './message_client'
import { useAuthorDirectory } from '../identity/author_directory'
import MessageBody from './MessageBody.vue'
import MentionPicker from './MentionPicker.vue'
import TextMessageAttachments from './TextMessageAttachments.vue'

type RenderedMessage = Omit<TextMessage, 'channelId' | 'attachments' | 'mentionUserIds'> & { channelId?: string; attachments?: TextMessageAttachment[]; mentionUserIds?: string[] }

const props = defineProps<{ message: RenderedMessage; replyPreview?: string; canEdit: boolean; canDelete: boolean; retryDisabled?: boolean; mentionRecipient?: { id: string; displayName: string } }>()
const emit = defineEmits<{ edit: [body: string, mentionUserIds: string[]]; remove: []; reply: []; retry: [] }>()
const editing = ref(false)
const body = ref('')
const editingMentionIds = ref<string[]>([])
const textChannelId = computed(() => props.message.channelId ?? '')
const textAttachments = computed(() => props.message.attachments ?? [])
const authors = useAuthorDirectory()
const authorName = computed(() => authors.displayName(props.message.authorId))
const authorAvatar = computed(() => authors.avatarUrl(props.message.authorId))
const avatarFailed = ref(false)
watch(() => props.message.authorId, (id) => { void authors.ensure(id) }, { immediate: true })
watch(() => props.message.mentionUserIds, (ids) => { for (const id of ids ?? []) void authors.ensure(id) }, { immediate: true })
watch(authorAvatar, () => { avatarFailed.value = false })

function beginEdit(): void {
  body.value = props.message.body
  editingMentionIds.value = [...(props.message.mentionUserIds ?? [])]
  editing.value = true
}

function saveEdit(): void {
  if (!body.value) return
  emit('edit', body.value, [...editingMentionIds.value])
  editing.value = false
}

function remove(): void {
  if (window.confirm('Удалить это сообщение?')) emit('remove')
}

function initial(name: string): string {
  return name.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У'
}
</script>

<template>
  <article class="message-item message-row" :class="{ deleted: message.deleted }">
    <img v-if="authorAvatar && !avatarFailed" class="message-avatar" :src="authorAvatar" alt="" @error="avatarFailed = true">
    <span v-else class="message-avatar" aria-hidden="true">{{ initial(authorName) }}</span>
    <div class="message-content">
      <div class="message-meta">
        <span class="message-author">{{ authorName }}</span>
        <time class="message-time">{{ new Date(message.createdAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) }}</time>
        <span v-if="message.editedAt" class="message-time">изменено</span>
      </div>
      <p v-if="message.deleted">Сообщение удалено</p>
      <template v-else-if="editing">
        <textarea v-model="body" maxlength="8000" aria-label="Изменённый текст сообщения" />
        <MentionPicker v-model="editingMentionIds" :self-id="message.authorId" :disabled="false" :only-participant="mentionRecipient" />
        <button type="button" @click="saveEdit">Сохранить</button>
        <button type="button" @click="editing = false">Отмена</button>
      </template>
      <template v-else>
        <p v-if="replyPreview" class="reply-preview">↪ {{ replyPreview }}</p>
        <MessageBody :body="message.body" />
        <p v-if="message.mentionUserIds?.length" class="message-mentions">Упомянуты: <span v-for="id in message.mentionUserIds" :key="id">@{{ authors.displayName(id) }} </span></p>
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
