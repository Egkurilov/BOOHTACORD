import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { MessageRequestError, type MessageRequest } from '../conversation/message_client'

export type MentionKind = 'CHANNEL' | 'DIRECT_MESSAGE'
export interface MentionInboxItem { kind: MentionKind; messageId: string; conversationId: string; authorId: string; createdAt: string }
export interface MentionInboxPage { mentions: MentionInboxItem[]; nextCursor?: string }

function invalid(): never { throw new Error('Сервер вернул некорректные результаты упоминаний.') }
function object(value: unknown): Record<string, unknown> | null { return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null }
function uuid(value: unknown): string { if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) return invalid(); return value }

function parseMention(value: unknown): MentionInboxItem {
  const source = object(value)
  if (!source || Object.keys(source).some((key) => !['kind', 'message_id', 'conversation_id', 'author_id', 'created_at'].includes(key)) || (source.kind !== 'CHANNEL' && source.kind !== 'DIRECT_MESSAGE') || typeof source.created_at !== 'string' || Number.isNaN(Date.parse(source.created_at))) return invalid()
  return { kind: source.kind, messageId: uuid(source.message_id), conversationId: uuid(source.conversation_id), authorId: uuid(source.author_id), createdAt: source.created_at }
}

export async function listMyMentions(before?: string, request: MessageRequest = tracedFetch): Promise<MentionInboxPage> {
  const parameters = new URLSearchParams()
  if (before) parameters.set('before', before)
  const query = parameters.toString()
  const response = await request(`${apiBaseUrl}/mentions${query ? `?${query}` : ''}`, { method: 'GET', credentials: 'same-origin', cache: 'no-store', headers: { accept: 'application/json' } })
  let payload: unknown = null
  try { payload = await response.json() } catch { /* Status is enough when the server returned no JSON. */ }
  if (!response.ok) throw new MessageRequestError(response.status, typeof object(object(payload)?.error)?.code === 'string' ? String(object(object(payload)?.error)?.code) : undefined)
  const source = object(payload)
  if (!source || Object.keys(source).some((key) => !['mentions', 'next_cursor'].includes(key)) || !Array.isArray(source.mentions) || (source.next_cursor !== undefined && (typeof source.next_cursor !== 'string' || !source.next_cursor || source.next_cursor.length > 512))) return invalid()
  return { mentions: source.mentions.map(parseMention), nextCursor: typeof source.next_cursor === 'string' ? source.next_cursor : undefined }
}
