import { defineStore } from 'pinia'
import { ref } from 'vue'

import { createTextMessage, deleteTextMessage, editTextMessage, type MessageRequest, type TextMessageAttachment } from './message_client'
import { createTextHistory, pendingMessage, type PendingSend } from './text_history'

export const useMessageStore = defineStore('text-messages', () => {
  const pending = new Map<string, PendingSend>()
  const { channelId, messages, nextCursor, loading, olderLoading, historyLoaded, error, olderError, open, refresh, loadOlder } = createTextHistory(pending)
  const sending = ref(false)
  const retries = new Map<string, string>()

  async function submit(clientMessageId: string, draft: PendingSend, request = draft.request): Promise<boolean> {
    const targetChannelId = draft.channelId
    if (sending.value || channelId.value !== targetChannelId) return false
    sending.value = true
    error.value = null
    draft.sendStatus = 'sending'
    const optimisticId = `optimistic:${clientMessageId}`
    messages.value = [pendingMessage(clientMessageId, draft), ...messages.value.filter((message) => message.clientMessageId !== clientMessageId)]
    try {
      const created = await createTextMessage(targetChannelId, clientMessageId, draft.body, request, draft.replyToId, draft.attachments.map(({ id }) => id), draft.mentionUserIds)
      pending.delete(clientMessageId)
      if (channelId.value !== targetChannelId) return false
      for (const [key, id] of retries) if (id === clientMessageId) retries.delete(key)
      messages.value = [{ ...created, attachments: [...draft.attachments] }, ...messages.value.filter((message) => message.id !== created.id && message.clientMessageId !== clientMessageId)]
      return true
    } catch (cause) {
      draft.sendStatus = 'failed'
      if (channelId.value === targetChannelId) {
        error.value = cause instanceof Error ? cause.message : 'Не удалось отправить сообщение.'
        messages.value = messages.value.map((message) => message.id === optimisticId ? { ...message, sendStatus: 'failed' } : message)
      }
      return false
    } finally { sending.value = false }
  }

  async function send(body: string, request?: MessageRequest, createId: () => string = () => crypto.randomUUID(), replyToId?: string, attachments: TextMessageAttachment[] = [], authorId = 'Вы', mentionUserIds: string[] = []): Promise<boolean> {
    const targetChannelId = channelId.value
    if (!targetChannelId || sending.value || !body) return false
    const draft = { channelId: targetChannelId, authorId, body, replyToId, attachments: [...attachments], mentionUserIds: [...mentionUserIds], request }
    const key = JSON.stringify([targetChannelId, authorId, body, replyToId, attachments.map(({ id }) => id), mentionUserIds])
    const clientMessageId = retries.get(key) ?? createId()
    pending.set(clientMessageId, draft)
    retries.set(key, clientMessageId)
    return submit(clientMessageId, draft)
  }

  async function retry(clientMessageId: string, request?: MessageRequest): Promise<boolean> {
    const draft = pending.get(clientMessageId)
    return draft ? submit(clientMessageId, draft, request ?? draft.request) : false
  }

  async function edit(messageId: string, body: string, expectedRevision: number, request?: MessageRequest, mentionUserIds?: string[]): Promise<boolean> {
    const targetChannelId = channelId.value
    if (!targetChannelId || !body) return false
    error.value = null
    try {
      const current = messages.value.find(({ id }) => id === messageId)
      const changed = await editTextMessage(targetChannelId, messageId, body, expectedRevision, request, mentionUserIds ?? current?.mentionUserIds ?? [])
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
      messages.value = messages.value.map((message) => message.id === messageId && !message.deleted ? { ...message, body: '', deleted: true, revision: message.revision + 1 } : message)
      return true
    } catch (cause) {
      if (channelId.value === targetChannelId) error.value = cause instanceof Error ? cause.message : 'Не удалось удалить сообщение.'
      return false
    }
  }

  return { channelId, edit, error, loading, olderLoading, historyLoaded, olderError, loadOlder, messages, nextCursor, open, refresh, remove, retry, send, sending }
})
