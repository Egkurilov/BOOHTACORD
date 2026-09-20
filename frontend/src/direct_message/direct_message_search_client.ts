import { apiBaseUrl } from '../config/runtime'
import type { DirectMessageRequest } from './direct_message_client'

export interface DirectMessageSearchResult {
  id: string
  directMessageId: string
  authorId: string
  body: string
  createdAt: string
  editedAt?: string
  revision: number
}

export interface DirectMessageSearchPage {
  messages: DirectMessageSearchResult[]
  nextCursor?: string
}

export class DirectMessageSearchRequestError extends Error {
  constructor(readonly status: number, readonly code?: string) {
    super(code ? `Поиск личных сообщений отклонён: ${code}.` : `Поиск личных сообщений отклонён (${status}).`)
  }
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}

function text(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

function malformed(): never {
  throw new Error('Сервер вернул некорректные результаты поиска личных сообщений.')
}

function result(value: unknown): DirectMessageSearchResult {
  const source = record(value)
  const id = text(source?.id)
  const directMessageId = text(source?.direct_message_id)
  const authorId = text(source?.author_id)
  const body = text(source?.body)
  const createdAt = text(source?.created_at)
  if (!source || !id || !directMessageId || !authorId || !body || !createdAt || Number.isNaN(Date.parse(createdAt)) || !Number.isInteger(source.revision) || (source.revision as number) < 1) {
    return malformed()
  }

  return { id, directMessageId, authorId, body, createdAt, editedAt: text(source.edited_at) ?? undefined, revision: source.revision as number }
}

async function checked(response: Response): Promise<unknown> {
  let body: unknown = null
  try { body = await response.json() } catch { /* The bounded status error is sufficient. */ }
  if (response.ok) return body
  const code = text(record(record(body)?.error)?.code) ?? undefined
  throw new DirectMessageSearchRequestError(response.status, code)
}

export async function searchDirectMessageHistory(directMessageId: string, query: string, before: string | undefined, limit = 50, request: DirectMessageRequest = fetch): Promise<DirectMessageSearchPage> {
  const parameters = new URLSearchParams({ query })
  if (before) parameters.set('before', before)
  parameters.set('limit', String(limit))
  const response = await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/search?${parameters}`, {
    method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' },
  })
  const source = record(await checked(response))
  if (!source || !Array.isArray(source.messages)) return malformed()
  return { messages: source.messages.map(result), nextCursor: text(source.next_cursor) ?? undefined }
}
