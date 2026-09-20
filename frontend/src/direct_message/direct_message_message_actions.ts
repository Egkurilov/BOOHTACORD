import type { Ref } from 'vue'

import type { DirectMessageHistoryItem, DirectMessageRequest } from './direct_message_client'
import { createDirectMessage, deleteDirectMessage, editDirectMessage } from './direct_message_mutation_client'

export interface DirectMessageActionState {
  directMessageId: Ref<string | null>
  error: Ref<string | null>
  messages: Ref<DirectMessageHistoryItem[]>
  sending: Ref<boolean>
}

export function createDirectMessageMessageActions(state: DirectMessageActionState) {
  async function send(body: string, request?: DirectMessageRequest, createId: () => string = () => crypto.randomUUID(), replyToId?: string): Promise<boolean> {
    const targetDirectMessageId = state.directMessageId.value
    if (!targetDirectMessageId || state.sending.value || !body) return false
    state.sending.value = true
    state.error.value = null
    try {
      const created = await createDirectMessage(targetDirectMessageId, createId(), body, request, replyToId)
      if (state.directMessageId.value !== targetDirectMessageId) return false
      state.messages.value = [created, ...state.messages.value.filter((message) => message.id !== created.id)]
      return true
    } catch (cause) {
      if (state.directMessageId.value === targetDirectMessageId) state.error.value = cause instanceof Error ? cause.message : 'Не удалось отправить личное сообщение.'
      return false
    } finally {
      state.sending.value = false
    }
  }

  async function edit(messageId: string, body: string, expectedRevision: number, request?: DirectMessageRequest): Promise<boolean> {
    const targetDirectMessageId = state.directMessageId.value
    if (!targetDirectMessageId || !body) return false
    state.error.value = null
    try {
      const changed = await editDirectMessage(targetDirectMessageId, messageId, body, expectedRevision, request)
      if (state.directMessageId.value !== targetDirectMessageId) return false
      state.messages.value = state.messages.value.map((message) => message.id === changed.id ? changed : message)
      return true
    } catch (cause) {
      if (state.directMessageId.value === targetDirectMessageId) state.error.value = cause instanceof Error ? cause.message : 'Не удалось изменить личное сообщение.'
      return false
    }
  }

  async function remove(messageId: string, request?: DirectMessageRequest): Promise<boolean> {
    const targetDirectMessageId = state.directMessageId.value
    if (!targetDirectMessageId) return false
    state.error.value = null
    try {
      await deleteDirectMessage(targetDirectMessageId, messageId, request)
      if (state.directMessageId.value !== targetDirectMessageId) return false
      state.messages.value = state.messages.value.map((message) => message.id === messageId ? { ...message, body: '', deleted: true, revision: message.revision + 1 } : message)
      return true
    } catch (cause) {
      if (state.directMessageId.value === targetDirectMessageId) state.error.value = cause instanceof Error ? cause.message : 'Не удалось удалить личное сообщение.'
      return false
    }
  }

  return { edit, remove, send }
}
