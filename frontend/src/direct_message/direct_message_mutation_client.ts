import { apiBaseUrl } from '../config/runtime'
import type { DirectMessageHistoryItem, DirectMessageRequest } from './direct_message_client'

export class DirectMessageMutationError extends Error {
  constructor(readonly status: number, readonly code?: string) {
    super(code ? `Запрос личного сообщения отклонён: ${code}.` : `Запрос личного сообщения отклонён (${status}).`)
  }
}

function invalid(): never { throw new Error('Сервер вернул некорректное личное сообщение.') }
function record(value: unknown): Record<string, unknown> | null { return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null }
function text(value: unknown): string | null { return typeof value === 'string' ? value : null }
function requiredText(value: unknown): string { const result = text(value); return result ? result : invalid() }
function messageBody(value: unknown): string { const result = text(value); return result === null || !result ? invalid() : result }
function date(value: unknown): string { const result = requiredText(value); return Number.isNaN(Date.parse(result)) ? invalid() : result }
function optionalText(value: unknown): string | undefined { if (value === undefined) return undefined; return requiredText(value) }
function optionalDate(value: unknown): string | undefined { return value === undefined ? undefined : date(value) }
function revision(value: unknown): number { return typeof value === 'number' && Number.isInteger(value) && value > 0 ? value : invalid() }

function message(value: unknown): DirectMessageHistoryItem {
  const source = record(value)
  if (!source) invalid()
  return {
    id: requiredText(source.id), directMessageId: requiredText(source.direct_message_id), authorId: requiredText(source.author_id),
    clientMessageId: requiredText(source.client_message_id), body: messageBody(source.body), replyToId: optionalText(source.reply_to_id),
    createdAt: date(source.created_at), editedAt: optionalDate(source.edited_at), revision: revision(source.revision), deleted: false,
  }
}

async function checked(response: Response): Promise<unknown> {
  let payload: unknown = null
  try { payload = await response.json() } catch { /* empty delete response */ }
  if (response.ok) return payload
  const code = text(record(record(payload)?.error)?.code) ?? undefined
  throw new DirectMessageMutationError(response.status, code)
}

function requestInit(method: 'POST' | 'PATCH' | 'DELETE', payload?: unknown): RequestInit {
  return {
    method,
    credentials: 'same-origin',
    headers: { accept: 'application/json', ...(payload === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(payload === undefined ? {} : { body: JSON.stringify(payload) }),
  }
}

function path(directMessageId: string, messageId?: string): string {
  if (!directMessageId || (messageId !== undefined && !messageId)) invalid()
  const base = `${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/messages`
  return messageId ? `${base}/${encodeURIComponent(messageId)}` : base
}

export async function createDirectMessage(directMessageId: string, clientMessageId: string, body: string, request: DirectMessageRequest = fetch, replyToId?: string): Promise<DirectMessageHistoryItem> {
  if (!clientMessageId || !body) invalid()
  const response = await request(path(directMessageId), requestInit('POST', { client_message_id: clientMessageId, body, ...(replyToId ? { reply_to_id: replyToId } : {}) }))
  return message(await checked(response))
}

export async function editDirectMessage(directMessageId: string, messageId: string, body: string, expectedRevision: number, request: DirectMessageRequest = fetch): Promise<DirectMessageHistoryItem> {
  if (!body || !Number.isInteger(expectedRevision) || expectedRevision < 1) invalid()
  const response = await request(path(directMessageId, messageId), requestInit('PATCH', { body, expected_revision: expectedRevision }))
  return message(await checked(response))
}

export async function deleteDirectMessage(directMessageId: string, messageId: string, request: DirectMessageRequest = fetch): Promise<void> {
  await checked(await request(path(directMessageId, messageId), requestInit('DELETE')))
}
