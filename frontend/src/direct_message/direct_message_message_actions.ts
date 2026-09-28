import type { Ref } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'

import type { DirectMessageRequest } from './direct_message_client'
import type { TextMessageAttachment } from '../conversation/message_client'
import { createDirectMessage, deleteDirectMessage, editDirectMessage, DirectMessageMutationError } from './direct_message_mutation_client'
import type { EditResult } from '../conversation/message_edit_controller'
import { pendingDirectMessage, pendingDirectMessageKey, type DirectMessageDisplayItem, type PendingDirectMessageSend } from './direct_message_pending'

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
  async function submit(clientMessageId: string, draft: PendingDirectMessageSend, request = draft.request): Promise<boolean> {
    if (state.sending.value || state.directMessageId.value !== draft.directMessageId) return false
    state.sending.value = true
    state.error.value = null
    draft.sendStatus = 'sending'
    state.messages.value = [pendingDirectMessage(clientMessageId, draft), ...state.messages.value.filter((message) => message.clientMessageId !== clientMessageId)]
    try {
      const created = await createDirectMessage(draft.directMessageId, clientMessageId, draft.body, request, draft.replyToId, draft.mentionUserIds, draft.attachments.map(({ id }) => id))
      state.acknowledge(clientMessageId)
      if (state.directMessageId.value !== draft.directMessageId) return true
      state.messages.value = [{ ...created, attachments: [...draft.attachments] }, ...state.messages.value.filter((message) => message.id !== created.id && message.clientMessageId !== clientMessageId)]
      return true
    } catch (cause) {
      if (state.pending.has(clientMessageId)) draft.sendStatus = 'failed'
      if (state.directMessageId.value === draft.directMessageId && state.pending.has(clientMessageId)) {
        state.error.value = cause instanceof Error ? cause.message : 'Не удалось отправить личное сообщение.'
        state.messages.value = state.messages.value.map((message) => message.clientMessageId === clientMessageId ? { ...message, sendStatus: 'failed' } : message)
      }
      return false
    } finally {
      state.sending.value = false
    }
  }

  async function send(body: string, request?: DirectMessageRequest, createId: () => string = () => crypto.randomUUID(), replyToId?: string, authorId = 'Вы', mentionUserIds: string[] = [], attachments: TextMessageAttachment[] = []): Promise<boolean> {
    const directMessageId = state.directMessageId.value
    if (!directMessageId || state.sending.value || (!body && attachments.length === 0)) return false
    if (body && !validCodePointLength(body, 1, 8000)) { state.error.value = 'Сообщение должно содержать до 8000 символов.'; return false }
    const draft: PendingDirectMessageSend = { directMessageId, authorId, body, replyToId, mentionUserIds: [...mentionUserIds], attachments: [...attachments], request, sendStatus: 'sending' }
    const key = pendingDirectMessageKey(draft)
    const id = state.retries.get(key) ?? createId()
    const saved = state.pending.get(id) ?? draft
    state.pending.set(id, saved)
    state.retries.set(key, id)
    return submit(id, saved)
  }

  async function retry(clientMessageId: string, request?: DirectMessageRequest): Promise<boolean> {
    const draft = state.pending.get(clientMessageId)
    return draft ? submit(clientMessageId, draft, request ?? draft.request) : false
  }

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
    const targetDirectMessageId = state.directMessageId.value
    if (!targetDirectMessageId) return false
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
