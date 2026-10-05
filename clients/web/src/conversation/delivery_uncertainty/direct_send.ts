import { getCurrentScope, onScopeDispose } from 'vue'
import type { DirectMessageActionState } from '../../direct_message/direct_message_message_actions'
import { createDirectMessage } from '../../direct_message/direct_message_mutation_client'
import { pendingDirectMessage, pendingDirectMessageKey, type PendingDirectMessageSend } from '../../direct_message/direct_message_pending'
import type { DirectMessageRequest } from '../../direct_message/direct_message_client'
import type { TextMessageAttachment } from '../message_client'
import { validCodePointLength } from '../../validation/unicode_limits/unicode_limits'
import { deliverWithRecovery, uncertainFailure } from './flow'
import { lookupDirectDelivery } from './lookup'
export function createDirectDelivery(state: DirectMessageActionState) {
  let closed = false
  if (getCurrentScope()) onScopeDispose(() => { closed = true; state.pending.clear(); state.retries.clear() })
  async function submit(id: string, draft: PendingDirectMessageSend, request = draft.request, retry = false): Promise<boolean> {
    if (closed || state.sending.value || state.directMessageId.value !== draft.directMessageId || draft.retryBlocked) return false
    state.sending.value = true; state.error.value = null
    const status = (value: 'sending' | 'checking') => {
      if (closed || !state.pending.has(id)) return
      draft.sendStatus = value
      if (state.directMessageId.value === draft.directMessageId) state.messages.value = [pendingDirectMessage(id, draft), ...state.messages.value.filter(row => row.clientMessageId !== id)]
    }
    try {
      const created = await deliverWithRecovery({
        post: () => createDirectMessage(draft.directMessageId, id, draft.body, request, draft.replyToId, draft.mentionUserIds, draft.attachments.map(row => row.id)),
        lookup: () => lookupDirectDelivery(draft.directMessageId, id, draft.authorId, request), status, active: () => !closed,
      }, retry)
      state.acknowledge(id)
      const confirmed = created.deleted ? created : { ...created, attachments: created.attachments.length ? created.attachments : [...draft.attachments] }
      if (state.directMessageId.value === draft.directMessageId) state.messages.value = [confirmed, ...state.messages.value.filter(row => row.id !== created.id && row.clientMessageId !== id)]
      return true
    } catch (cause) {
      if (closed) return false
      draft.sendStatus = 'failed'; draft.retryBlocked = !uncertainFailure(cause)
      if (state.directMessageId.value === draft.directMessageId && state.pending.has(id)) {
        state.error.value = cause instanceof Error ? cause.message : 'Не удалось отправить личное сообщение.'
        state.messages.value = state.messages.value.map(row => row.clientMessageId === id ? { ...row, sendStatus: 'failed', retryBlocked: draft.retryBlocked } : row)
      }
      return false
    } finally { if (!closed) state.sending.value = false }
  }
  async function send(body: string, request?: DirectMessageRequest, createId: () => string = () => crypto.randomUUID(), replyToId?: string, authorId = 'Вы', mentionUserIds: string[] = [], attachments: TextMessageAttachment[] = []): Promise<boolean> {
    const conversation = state.directMessageId.value
    if (!conversation || closed || state.sending.value || (!body && !attachments.length)) return false
    if (body && !validCodePointLength(body, 1, 8000)) { state.error.value = 'Сообщение должно содержать до 8000 символов.'; return false }
    const fresh: PendingDirectMessageSend = { directMessageId: conversation, authorId, body, replyToId, attachments: [...attachments], mentionUserIds: [...mentionUserIds], request, sendStatus: 'sending' }
    const key = pendingDirectMessageKey(fresh), id = state.retries.get(key) ?? createId(), previous = state.pending.get(id), draft = previous ?? fresh
    state.pending.set(id, draft); state.retries.set(key, id)
    return submit(id, draft, request ?? draft.request, Boolean(previous))
  }
  function retry(id: string, request?: DirectMessageRequest): Promise<boolean> { const draft = state.pending.get(id); return draft ? submit(id, draft, request ?? draft.request, true) : Promise.resolve(false) }
  function discard(messageId: string): boolean {
    if (!messageId.startsWith('optimistic:')) return false
    const id = messageId.slice('optimistic:'.length), draft = state.pending.get(id)
    if (!draft || draft.sendStatus !== 'failed') return false
    state.acknowledge(id); state.messages.value = state.messages.value.filter(row => row.clientMessageId !== id); return true
  }
  return { send, retry, discard }
}
