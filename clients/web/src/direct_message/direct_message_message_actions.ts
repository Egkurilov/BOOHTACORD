import type { Ref } from 'vue'
import { createDirectDelivery } from '../conversation/delivery_uncertainty/direct_send'

import type { DirectMessageRequest } from './direct_message_client'
import { deleteDirectMessage, editDirectMessage, DirectMessageMutationError } from './direct_message_mutation_client'
import type { EditResult } from '../conversation/message_edit_controller'
import { type DirectMessageDisplayItem, type PendingDirectMessageSend } from './direct_message_pending'

export interface DirectMessageActionState {
  directMessageId: Ref<string | null>
  error: Ref<string | null>
  messages: Ref<DirectMessageDisplayItem[]>
  sending: Ref<boolean>
  pending: Map<string, PendingDirectMessageSend>
  retries: Map<string, string>
  acknowledge: (id: string) => void
}

export function createDirectMessageMessageActions(state: DirectMessageActionState) {
  const { send, retry, discard } = createDirectDelivery(state)

  async function editWithResult(messageId: string, body: string, expectedRevision: number, request?: DirectMessageRequest, mentionUserIds?: string[]): Promise<EditResult> {
    const targetDirectMessageId = state.directMessageId.value
    if (!targetDirectMessageId || !body) return { kind: 'stale', message: 'Личное сообщение недоступно.' }
    state.error.value = null
    try {
      const current = state.messages.value.find(({ id }) => id === messageId)
      const changed = await editDirectMessage(targetDirectMessageId, messageId, body, expectedRevision, request, mentionUserIds ?? current?.mentionUserIds ?? [])
      if (state.directMessageId.value !== targetDirectMessageId) return { kind: 'stale', message: 'Беседа изменилась.' }
      state.messages.value = state.messages.value.map((message) => message.id === changed.id ? { ...changed, attachments: message.attachments } : message)
      return { kind: 'saved' }
    } catch (cause) {
      const message = cause instanceof DirectMessageMutationError && cause.status === 409
        ? 'Сообщение изменилось. Обновите версию, чтобы сохранить свой текст.'
        : cause instanceof Error ? cause.message : 'Не удалось изменить личное сообщение.'
      if (state.directMessageId.value === targetDirectMessageId) state.error.value = message
      return { kind: cause instanceof DirectMessageMutationError && cause.status === 409 ? 'conflict' : 'error', message }
    }
  }

  async function edit(messageId: string, body: string, expectedRevision: number, request?: DirectMessageRequest, mentionUserIds?: string[]): Promise<boolean> {
    return (await editWithResult(messageId, body, expectedRevision, request, mentionUserIds)).kind === 'saved'
  }

  async function remove(messageId: string, request?: DirectMessageRequest): Promise<boolean> {
    if (discard(messageId)) return true
    const targetDirectMessageId = state.directMessageId.value
    if (!targetDirectMessageId || messageId.startsWith('optimistic:')) return false
    state.error.value = null
    try {
      await deleteDirectMessage(targetDirectMessageId, messageId, request)
      if (state.directMessageId.value !== targetDirectMessageId) return false
      state.messages.value = state.messages.value.map((message) => message.id === messageId ? { ...message, body: '', deleted: true, attachments: [], revision: message.revision + 1 } : message)
      return true
    } catch (cause) {
      if (state.directMessageId.value === targetDirectMessageId) state.error.value = cause instanceof Error ? cause.message : 'Не удалось удалить личное сообщение.'
      return false
    }
  }

  return { edit, editWithResult, remove, retry, send }
}
