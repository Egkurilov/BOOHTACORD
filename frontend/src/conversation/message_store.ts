import { defineStore } from 'pinia'
import { ref } from 'vue'

import { createTextMessage, deleteTextMessage, editTextMessage, loadMessagePage, type MessageRequest, type TextMessage, type TextMessageAttachment } from './message_client'

export const useMessageStore = defineStore('text-messages', () => {
  const channelId = ref<string | null>(null)
  const messages = ref<TextMessage[]>([])
  const nextCursor = ref<string | undefined>()
  const loading = ref(false)
  const sending = ref(false)
  const error = ref<string | null>(null)
  let loadSequence = 0

  async function open(nextChannelId: string, request?: MessageRequest): Promise<void> {
    if (channelId.value === nextChannelId) return
    channelId.value = nextChannelId
    messages.value = []
    nextCursor.value = undefined
    await refresh(request)
  }

  async function refresh(request?: MessageRequest): Promise<void> {
    const targetChannelId = channelId.value
    if (!targetChannelId) return
    const sequence = ++loadSequence
    loading.value = true
    error.value = null
    try {
      const page = await loadMessagePage(targetChannelId, undefined, request)
      if (channelId.value !== targetChannelId || sequence !== loadSequence) return
      messages.value = page.messages
      nextCursor.value = page.nextCursor
    } catch (cause) {
      if (channelId.value === targetChannelId && sequence === loadSequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить историю сообщений.'
    } finally {
      if (sequence === loadSequence) loading.value = false
    }
  }

  async function send(body: string, request?: MessageRequest, createId: () => string = () => crypto.randomUUID(), replyToId?: string, attachments: TextMessageAttachment[] = []): Promise<boolean> {
    const targetChannelId = channelId.value
    if (!targetChannelId || sending.value || !body) return false
    sending.value = true
    error.value = null
    try {
      const created = await createTextMessage(targetChannelId, createId(), body, request, replyToId, attachments.map(({ id }) => id))
      if (channelId.value !== targetChannelId) return false
      messages.value = [{ ...created, attachments: [...attachments] }, ...messages.value.filter((message) => message.id !== created.id)]
      return true
    } catch (cause) {
      if (channelId.value === targetChannelId) error.value = cause instanceof Error ? cause.message : 'Не удалось отправить сообщение.'
      return false
    } finally {
      sending.value = false
    }
  }

  async function edit(messageId: string, body: string, expectedRevision: number, request?: MessageRequest): Promise<boolean> {
    const targetChannelId = channelId.value
    if (!targetChannelId || !body) return false
    error.value = null
    try {
      const changed = await editTextMessage(targetChannelId, messageId, body, expectedRevision, request)
      if (channelId.value !== targetChannelId) return false
      messages.value = messages.value.map((message) => message.id === changed.id ? changed : message)
      return true
    } catch (cause) {
      if (channelId.value === targetChannelId) error.value = cause instanceof Error ? cause.message : 'Не удалось изменить сообщение.'
      return false
    }
  }

  async function remove(messageId: string, request?: MessageRequest): Promise<boolean> {
    const targetChannelId = channelId.value
    if (!targetChannelId) return false
    error.value = null
    try {
      await deleteTextMessage(targetChannelId, messageId, request)
      if (channelId.value !== targetChannelId) return false
      messages.value = messages.value.map((message) => message.id === messageId ? { ...message, body: '', deleted: true, revision: message.revision + 1 } : message)
      return true
    } catch (cause) {
      if (channelId.value === targetChannelId) error.value = cause instanceof Error ? cause.message : 'Не удалось удалить сообщение.'
      return false
    }
  }

  return { channelId, edit, error, loading, messages, nextCursor, open, refresh, remove, send, sending }
})
