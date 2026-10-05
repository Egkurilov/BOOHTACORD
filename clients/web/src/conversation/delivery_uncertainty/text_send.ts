import { onScopeDispose, type Ref } from 'vue'
import { createTextMessage, type MessageRequest, type TextMessage, type TextMessageAttachment } from '../message_client'
import { pendingMessage, type PendingSend } from '../text_history'
import { validCodePointLength } from '../../validation/unicode_limits/unicode_limits'
import { deliverWithRecovery, uncertainFailure } from './flow'
import { lookupTextDelivery } from './lookup'
import { journeyRecorder,markAccepted } from '../../telemetry/journey_intervals/runtime'
interface State { channelId: Ref<string | null>; sending: Ref<boolean>; error: Ref<string | null>; messages: Ref<TextMessage[]>; pending: Map<string, PendingSend>; retries: Map<string, string> }
export function createTextDelivery(state: State) {
  let closed = false
  onScopeDispose(() => { closed = true; state.pending.clear(); state.retries.clear() })
  function acknowledge(id: string): void { state.pending.delete(id); for (const [key, value] of state.retries) if (value === id) state.retries.delete(key) }
  async function submit(id: string, draft: PendingSend, request = draft.request, retry = false): Promise<boolean> {
    if (closed || state.sending.value || state.channelId.value !== draft.channelId || draft.retryBlocked) return false
    state.sending.value = true; state.error.value = null
    const finish=journeyRecorder.begin('send_ack')
    const status = (value: 'sending' | 'checking') => {
      if (closed || !state.pending.has(id)) return
      draft.sendStatus = value
      if (state.channelId.value === draft.channelId) state.messages.value = [pendingMessage(id, draft), ...state.messages.value.filter(row => row.clientMessageId !== id)]
    }
    try {
      const created = await deliverWithRecovery({
        post: () => createTextMessage(draft.channelId, id, draft.body, request, draft.replyToId, draft.attachments.map(row => row.id), draft.mentionUserIds),
        lookup: () => lookupTextDelivery(draft.channelId, id, draft.authorId, request), status, active: () => !closed,
      }, retry)
      acknowledge(id)
      finish('completed')
      const confirmed = created.deleted ? created : { ...created, attachments: created.attachments.length ? created.attachments : [...draft.attachments] }
      markAccepted(confirmed)
      if (state.channelId.value === draft.channelId) state.messages.value = [confirmed, ...state.messages.value.filter(row => row.id !== created.id && row.clientMessageId !== id)]
      return true
    } catch (cause) {
      finish('failed')
      if (closed) return false
      draft.sendStatus = 'failed'; draft.retryBlocked = !uncertainFailure(cause)
      if (state.channelId.value === draft.channelId && state.pending.has(id)) {
        state.error.value = cause instanceof Error ? cause.message : 'Не удалось отправить сообщение.'
        state.messages.value = state.messages.value.map(row => row.clientMessageId === id ? { ...row, sendStatus: 'failed', retryBlocked: draft.retryBlocked } : row)
      }
      return false
    } finally { if (!closed) state.sending.value = false }
  }
  async function send(body: string, request?: MessageRequest, createId: () => string = () => crypto.randomUUID(), replyToId?: string, attachments: TextMessageAttachment[] = [], authorId = 'Вы', mentionUserIds: string[] = []): Promise<boolean> {
    const channel = state.channelId.value
    if (!channel || closed || state.sending.value || (!body && !attachments.length)) return false
    if (body && !validCodePointLength(body, 1, 8000)) { state.error.value = 'Сообщение должно содержать до 8000 символов.'; return false }
    const key = JSON.stringify([channel, authorId, body, replyToId, attachments.map(row => row.id), mentionUserIds])
    const id = state.retries.get(key) ?? createId(), previous = state.pending.get(id)
    const draft: PendingSend = previous ?? { channelId: channel, authorId, body, replyToId, attachments: [...attachments], mentionUserIds: [...mentionUserIds], request }
    state.pending.set(id, draft); state.retries.set(key, id)
    return submit(id, draft, request ?? draft.request, Boolean(previous))
  }
  function retry(id: string, request?: MessageRequest): Promise<boolean> { const draft = state.pending.get(id); return draft ? submit(id, draft, request ?? draft.request, true) : Promise.resolve(false) }
  function discard(messageId: string): boolean {
    if (!messageId.startsWith('optimistic:')) return false
    const id = messageId.slice('optimistic:'.length), draft = state.pending.get(id)
    if (!draft || draft.sendStatus !== 'failed') return false
    acknowledge(id); state.messages.value = state.messages.value.filter(row => row.clientMessageId !== id); return true
  }
  return { send, retry, discard }
}
