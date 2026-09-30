import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { MessageRequestError, type MessageRequest } from './message_client'

export interface TextMessageSearchResult {
  id: string
  channelId: string
  authorId: string
  body: string
  createdAt: string
  editedAt?: string
  revision: number
}

export interface TextMessageSearchPage {
  messages: TextMessageSearchResult[]
  nextCursor?: string
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}

function text(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

function malformed(): never {
  throw new Error('Сервер вернул некорректные результаты поиска сообщений.')
}

function result(value: unknown): TextMessageSearchResult {
  const source = record(value)
  const id = text(source?.id)
  const channelId = text(source?.channel_id)
  const authorId = text(source?.author_id)
  const body = text(source?.body)
  const createdAt = text(source?.created_at)
  if (!source || !id || !channelId || !authorId || !body || !createdAt || Number.isNaN(Date.parse(createdAt)) || !Number.isInteger(source.revision) || (source.revision as number) < 1) {
    return malformed()
  }

  return { id, channelId, authorId, body, createdAt, editedAt: text(source.edited_at) ?? undefined, revision: source.revision as number }
}

async function checked(response: Response): Promise<unknown> {
  let body: unknown = null
  try { body = await response.json() } catch { /* The bounded status error is sufficient. */ }
  if (response.ok) return body
  const code = text(record(record(body)?.error)?.code) ?? undefined
  throw new MessageRequestError(response.status, code)
}

export async function searchTextMessages(channelId: string, query: string, before: string | undefined, limit = 50, request: MessageRequest = tracedFetch): Promise<TextMessageSearchPage> {
  const parameters = new URLSearchParams({ query })
  if (before) parameters.set('before', before)
  parameters.set('limit', String(limit))
  const response = await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/search?${parameters}`, {
    method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' },
  })
  const source = record(await checked(response))
  if (!source || !Array.isArray(source.messages)) return malformed()
  const nextCursor = text(source.next_cursor) ?? undefined
  return { messages: source.messages.map(result), nextCursor }
}
