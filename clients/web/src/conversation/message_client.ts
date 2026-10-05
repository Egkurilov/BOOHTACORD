import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { parseMentionIds } from './mention_ids'
import { parseMessageKind, type MessageKind } from './system_welcome/kind'

export interface TextMessageAttachment {
  id: string
  originalName: string
  sizeBytes: number
}

export interface TextMessage {
  kind?: MessageKind
  id: string
  channelId: string
  authorId: string
  clientMessageId: string
  body: string
  replyToId?: string
  revision: number
  createdAt: string
  editedAt?: string
  deleted: boolean
  attachments: TextMessageAttachment[]
  mentionUserIds: string[]
  retryBlocked?: boolean
  sendStatus?: 'sending' | 'checking' | 'failed'
}
export interface MessagePage {
  messages: TextMessage[]
  nextCursor?: string
}
export type MessageRequest = (input: string, init: RequestInit) => Promise<Response>

export class MessageRequestError extends Error {
  constructor(readonly status: number, readonly code?: string) {
    super(code ? `Запрос сообщения отклонён: ${code}.` : `Запрос сообщения отклонён (${status}).`)
  }
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}

function text(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

function attachments(value: unknown, required: boolean): TextMessageAttachment[] {
  if (value === undefined && !required) return []
  if (!Array.isArray(value)) throw new Error('Сервер вернул некорректное сообщение.')
  return value.map((candidate) => {
    const source = record(candidate)
    const id = text(source?.id)
    const originalName = text(source?.original_name)
    const sizeBytes = source?.byte_size
    if (!source || !id || !originalName || !Number.isInteger(sizeBytes) || (sizeBytes as number) < 0 || (sizeBytes as number) > 25_000_000) {
      throw new Error('Сервер вернул некорректное сообщение.')
    }
    return { id, originalName, sizeBytes: sizeBytes as number }
  })
}

function message(value: unknown, requireAttachments = false): TextMessage {
  const source = record(value)
  const id = text(source?.id)
  const channelId = text(source?.channel_id)
  const authorId = text(source?.author_id)
  const clientMessageId = text(source?.client_message_id)
  const body = text(source?.body)
  const createdAt = text(source?.created_at)
  if (!source || !id || !channelId || !authorId || !clientMessageId || body === null || !createdAt || Number.isNaN(Date.parse(createdAt)) || !Number.isInteger(source.revision) || (source.revision as number) < 1 || (source.deleted !== undefined && typeof source.deleted !== 'boolean')) {
    throw new Error('Сервер вернул некорректное сообщение.')
  }
  const replyToId = text(source.reply_to_id) ?? undefined
  const editedAt = text(source.edited_at) ?? undefined
  const kind = parseMessageKind(source.kind)
  return { ...(source.kind === undefined ? {} : { kind }), id, channelId, authorId, clientMessageId, body, replyToId, revision: source.revision as number, createdAt, editedAt, deleted: source.deleted === true, attachments: attachments(source.attachments, requireAttachments), mentionUserIds: parseMentionIds(source.mention_user_ids) }
}

async function checked(response: Response): Promise<unknown> {
  let body: unknown = null
  try { body = await response.json() } catch { /* empty response */ }
  if (response.ok) return body
  throw new MessageRequestError(response.status, text(record(record(body)?.error)?.code) ?? undefined)
}

function requestInit(method: string, body?: unknown): RequestInit {
  return { method, credentials: 'same-origin', headers: { accept: 'application/json', ...(body ? { 'content-type': 'application/json' } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) }
}

export async function loadMessagePage(channelId: string, before: string | undefined, request: MessageRequest = tracedFetch, at?: string, after?: string): Promise<MessagePage> {
  if ((before && at) || (after && (before || at))) throw new Error('Выберите один курсор истории.')
  const query = after ? `?after=${encodeURIComponent(after)}&limit=20` : at ? `?at=${encodeURIComponent(at)}&limit=20` : before ? `?before=${encodeURIComponent(before)}` : ''
  const response = await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/messages${query}`, requestInit('GET'))
  const source = record(await checked(response))
  if (!source || !Array.isArray(source.messages)) throw new Error('Сервер вернул некорректную историю сообщений.')
  const nextCursor = text(source.next_cursor) ?? undefined
  return { messages: source.messages.map((value) => message(value, true)), nextCursor }
}

export async function createTextMessage(channelId: string, clientMessageId: string, body: string, request: MessageRequest = tracedFetch, replyToId?: string, attachmentIds: string[] = [], mentionUserIds: string[] = []): Promise<TextMessage> {
  const response = await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/messages`, requestInit('POST', {
    client_message_id: clientMessageId,
    body,
    ...(replyToId ? { reply_to_id: replyToId } : {}),
    ...(attachmentIds.length ? { attachment_ids: attachmentIds } : {}),
    ...(mentionUserIds.length ? { mention_user_ids: mentionUserIds } : {}),
  }))
  return message(await checked(response))
}

export async function editTextMessage(channelId: string, messageId: string, body: string, expectedRevision: number, request: MessageRequest = tracedFetch, mentionUserIds: string[] = []): Promise<TextMessage> {
  const response = await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/messages/${encodeURIComponent(messageId)}`, requestInit('PATCH', { body, expected_revision: expectedRevision, ...(mentionUserIds.length ? { mention_user_ids: mentionUserIds } : {}) }))
  return message(await checked(response))
}

export async function deleteTextMessage(channelId: string, messageId: string, request: MessageRequest = tracedFetch): Promise<void> {
  await checked(await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/messages/${encodeURIComponent(messageId)}`, requestInit('DELETE')))
}
