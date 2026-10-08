import { parseMessageKind, type MessageKind } from '../conversation/system_welcome/kind'
import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { MessageRequestError, type MessageRequest } from '../conversation/message_client'

export type SearchConversationKind = 'CHANNEL' | 'DIRECT_MESSAGE'
export interface SearchMessagesInput { query: string; channelId?: string; directMessageId?: string; authorId?: string; hasAttachment?: boolean; createdFrom?: string; createdBefore?: string; before?: string; limit?: number }
interface SearchMessageBase { messageKind?: MessageKind; id: string; kind: SearchConversationKind; authorId: string; body: string; createdAt: string; editedAt?: string; revision: number }
export type SearchMessage = SearchMessageBase & ({ kind: 'CHANNEL'; channelId: string; directMessageId?: never } | { kind: 'DIRECT_MESSAGE'; directMessageId: string; channelId?: never })
export interface SearchMessagesPage { messages: SearchMessage[]; nextCursor?: string }

function invalid(): never { throw new Error('Сервер вернул некорректные результаты поиска сообщений.') }
function record(value: unknown): Record<string, unknown> | null { return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null }
function text(value: unknown): string | null { return typeof value === 'string' ? value : null }
function uuid(value: unknown): string { const result = text(value); return result && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(result) ? result : invalid() }
function date(value: unknown): string { const result = text(value); return result && !Number.isNaN(Date.parse(result)) ? result : invalid() }

function parseMessage(value: unknown): SearchMessage {
  const source = record(value)
  if (!source || (source.kind !== 'CHANNEL' && source.kind !== 'DIRECT_MESSAGE') || typeof source.body !== 'string' || !source.body || !Number.isInteger(source.revision) || (source.revision as number) < 1) return invalid()
  const messageKind = parseMessageKind(source.message_kind)
  const common = { ...(source.message_kind === undefined ? {} : { messageKind }), id: uuid(source.id), authorId: uuid(source.author_id), body: source.body, createdAt: date(source.created_at), editedAt: source.edited_at === undefined ? undefined : date(source.edited_at), revision: source.revision as number }
  if (source.kind === 'CHANNEL') {
    if (source.direct_message_id !== undefined) return invalid()
    return { ...common, kind: 'CHANNEL', channelId: uuid(source.channel_id) }
  }
  if (source.channel_id !== undefined) return invalid()
  return { ...common, kind: 'DIRECT_MESSAGE', directMessageId: uuid(source.direct_message_id) }
}

async function checked(response: Response): Promise<unknown> {
  let payload: unknown = null
  try { payload = await response.json() } catch { /* The bounded HTTP status is enough. */ }
  if (response.ok) return payload
  const code = text(record(record(payload)?.error)?.code) ?? undefined
  throw new MessageRequestError(response.status, code)
}

export async function searchMessages(input: SearchMessagesInput, request: MessageRequest = tracedFetch): Promise<SearchMessagesPage> {
  if (input.channelId && input.directMessageId) throw new Error('Выберите один фильтр беседы.')
  const parameters = new URLSearchParams({ query: input.query })
  if (input.channelId) parameters.set('channel_id', input.channelId)
  if (input.directMessageId) parameters.set('direct_message_id', input.directMessageId)
  if (input.authorId) parameters.set('author_id', input.authorId)
  if (input.hasAttachment !== undefined) parameters.set('has_attachment', String(input.hasAttachment))
  if (input.createdFrom) parameters.set('created_from', input.createdFrom)
  if (input.createdBefore) parameters.set('created_before', input.createdBefore)
  if (input.before) parameters.set('before', input.before)
  if (input.limit !== undefined) parameters.set('limit', String(input.limit))
  const response = await request(`${apiBaseUrl}/search/messages?${parameters}`, { method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' } })
  const source = record(await checked(response))
  if (!source || !Array.isArray(source.messages) || (source.next_cursor !== undefined && (typeof source.next_cursor !== 'string' || !source.next_cursor || source.next_cursor.length > 512))) return invalid()
  return { messages: source.messages.map(parseMessage), nextCursor: text(source.next_cursor) ?? undefined }
}
