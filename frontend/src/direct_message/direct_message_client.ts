import { apiBaseUrl } from '../config/runtime'

export { loadDirectMessages, type DirectMessageListItem } from './direct_message_navigation_client'

export interface DirectMessageReplyPreview {
  id: string
  authorId: string
  body: string
  deleted: boolean
}

export interface DirectMessageHistoryItem {
  id: string
  directMessageId: string
  authorId: string
  clientMessageId: string
  body: string
  replyToId?: string
  replyPreview?: DirectMessageReplyPreview
  createdAt: string
  editedAt?: string
  revision: number
  deleted: boolean
}

export interface DirectMessageHistoryPage {
  messages: DirectMessageHistoryItem[]
  nextCursor?: string
}

export interface DirectMessageReadCursor {
  directMessageId: string
  messageId: string
  messageCreatedAt: string
}

export type DirectMessageRequest = (input: string, init: RequestInit) => Promise<Response>

function invalidHistory(): never { throw new Error('Сервер вернул некорректную историю личных сообщений.') }
function record(value: unknown): Record<string, unknown> | null { return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null }
function text(value: unknown): string | null { return typeof value === 'string' ? value : null }
function requiredText(value: unknown, invalid: () => never): string { const result = text(value); return result ? result : invalid() }
function body(value: unknown): string { const result = text(value); return result === null ? invalidHistory() : result }
function optionalText(value: unknown): string | undefined { if (value === undefined) return undefined; return requiredText(value, invalidHistory) }
function date(value: unknown): string { const result = requiredText(value, invalidHistory); return Number.isNaN(Date.parse(result)) ? invalidHistory() : result }
function optionalDate(value: unknown): string | undefined { return value === undefined ? undefined : date(value) }
function deleted(value: unknown): boolean { return typeof value === 'boolean' ? value : invalidHistory() }
function revision(value: unknown): number { return typeof value === 'number' && Number.isInteger(value) && value > 0 ? value : invalidHistory() }

function replyPreview(value: unknown): DirectMessageReplyPreview | undefined {
  if (value === undefined) return undefined
  const source = record(value)
  if (!source) invalidHistory()
  const previewBody = body(source.body)
  const previewDeleted = deleted(source.deleted)
  if (previewDeleted && previewBody !== '') invalidHistory()
  return { id: requiredText(source.id, invalidHistory), authorId: requiredText(source.author_id, invalidHistory), body: previewBody, deleted: previewDeleted }
}

function historyItem(value: unknown): DirectMessageHistoryItem {
  const source = record(value)
  if (!source) invalidHistory()
  const messageBody = body(source.body)
  const messageDeleted = deleted(source.deleted)
  if (messageDeleted && messageBody !== '') invalidHistory()
  return {
    id: requiredText(source.id, invalidHistory), directMessageId: requiredText(source.direct_message_id, invalidHistory),
    authorId: requiredText(source.author_id, invalidHistory), clientMessageId: requiredText(source.client_message_id, invalidHistory),
    body: messageBody, replyToId: optionalText(source.reply_to_id), replyPreview: replyPreview(source.reply_preview),
    createdAt: date(source.created_at), editedAt: optionalDate(source.edited_at), revision: revision(source.revision), deleted: messageDeleted,
  }
}

function readCursor(value: unknown): DirectMessageReadCursor {
  const source = record(value)
  if (!source) invalidHistory()
  return {
    directMessageId: requiredText(source.direct_message_id, invalidHistory),
    messageId: requiredText(source.message_id, invalidHistory),
    messageCreatedAt: date(source.message_created_at),
  }
}

async function checked(response: Response): Promise<unknown> {
  if (response.ok) return response.json()
  throw new Error(`Не удалось загрузить личные сообщения (${response.status}).`)
}

function requestInit(method: 'GET' | 'PUT', body?: unknown): RequestInit {
  return {
    method,
    credentials: 'same-origin',
    headers: { accept: 'application/json', ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  }
}

export async function loadDirectMessageHistory(directMessageId: string, before: string | undefined, request: DirectMessageRequest = fetch): Promise<DirectMessageHistoryPage> {
  if (!directMessageId) invalidHistory()
  const query = before ? `?before=${encodeURIComponent(before)}` : ''
  const source = record(await checked(await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/messages${query}`, requestInit('GET'))))
  if (!source || !Array.isArray(source.messages)) invalidHistory()
  return { messages: source.messages.map(historyItem), nextCursor: optionalText(source.next_cursor) }
}

export async function advanceDirectMessageReadCursor(directMessageId: string, messageId: string, request: DirectMessageRequest = fetch): Promise<DirectMessageReadCursor> {
  if (!directMessageId || !messageId) invalidHistory()
  const response = await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/read-cursor`, requestInit('PUT', { message_id: messageId }))
  return readCursor(await checked(response))
}
