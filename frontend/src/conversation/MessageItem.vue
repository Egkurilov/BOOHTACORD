<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import type { TextMessage, TextMessageAttachment } from './message_client'
import { useAuthorDirectory } from '../identity/author_directory'
import MessageBody from './MessageBody.vue'
import MentionPicker from './MentionPicker.vue'
import TextMessageAttachments from './TextMessageAttachments.vue'
import DirectMessageAttachments from '../direct_message/DirectMessageAttachments.vue'
import { useMessageEditController, type EditResult } from './message_edit_controller'

type RenderedMessage = Omit<TextMessage, 'channelId' | 'attachments' | 'mentionUserIds'> & { channelId?: string; directMessageId?: string; attachments?: TextMessageAttachment[]; mentionUserIds?: string[] }

const props = defineProps<{ message: RenderedMessage; replyPreview?: string; canEdit: boolean; canDelete: boolean; retryDisabled?: boolean; mentionRecipient?: { id: string; displayName: string }; editMessage?: (body: string, mentionIds: string[], revision: number) => Promise<EditResult>; refreshMessage?: () => Promise<{ revision: number; deleted: boolean } | null> }>()
const emit = defineEmits<{ remove: []; reply: []; retry: [] }>()
const editor = useMessageEditController({
  save: (body, ids, revision) => props.editMessage?.(body, ids, revision) ?? Promise.resolve({ kind: 'stale', message: 'Сообщение недоступно.' }),
  refresh: () => props.refreshMessage?.() ?? Promise.resolve(null),
})
const { editing, body, mentionUserIds: editingMentionIds, pending, needsRefresh, error: editError, notice: editNotice } = editor
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
  editor.begin(props.message)
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
      <template v-if="editing">
        <textarea v-model="body" :disabled="pending" aria-label="Изменённый текст сообщения" :aria-describedby="editError ? `message-edit-error-${message.id}` : undefined" />
        <MentionPicker v-model="editingMentionIds" :self-id="message.authorId" :disabled="pending" :only-participant="mentionRecipient" />
        <p v-if="editError" :id="`message-edit-error-${message.id}`" class="message-send-status" role="alert">{{ editError }}</p>
        <p v-if="editNotice" class="message-send-status" role="status">{{ editNotice }}</p>
        <button type="button" :disabled="pending || needsRefresh || !body" @click="editor.submit()">{{ pending ? 'Обрабатываем…' : 'Сохранить' }}</button>
        <button v-if="needsRefresh" type="button" :disabled="pending" @click="editor.refreshVersion()">Обновить версию</button>
        <button type="button" :disabled="pending" @click="editor.cancel()">Отмена</button>
      </template>
      <p v-else-if="message.deleted">Сообщение удалено</p>
      <template v-else>
        <p v-if="replyPreview" class="reply-preview">↪ {{ replyPreview }}</p>
        <MessageBody :body="message.body" />
        <p v-if="message.mentionUserIds?.length" class="message-mentions">Упомянуты: <span v-for="id in message.mentionUserIds" :key="id">@{{ authors.displayName(id) }} </span></p>
        <TextMessageAttachments v-if="textChannelId && textAttachments.length" :channel-id="textChannelId" :attachments="textAttachments" />
        <DirectMessageAttachments v-if="message.directMessageId && textAttachments.length" :direct-message-id="message.directMessageId" :attachments="textAttachments" />
        <p v-if="message.sendStatus === 'sending'" class="message-send-status" role="status">Отправляется…</p>
        <div v-if="message.sendStatus === 'failed'" class="message-send-status" role="alert"><span>Не отправлено</span><button type="button" :disabled="retryDisabled" @click="emit('retry')">Повторить отправку</button></div>
      </template>
      <p v-if="!editing && !message.deleted && !message.sendStatus" class="message-actions">
        <button type="button" @click="emit('reply')">Ответить</button>
        <button v-if="canEdit" type="button" @click="beginEdit">Изменить</button>
        <button v-if="canDelete" type="button" @click="remove">Удалить</button>
      </p>
    </div>
  </article>
</template>
