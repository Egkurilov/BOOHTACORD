import { apiBaseUrl } from '../config/runtime'
import type { DirectMessageRequest } from './direct_message_client'

export interface DirectMessageCandidate { id: string; displayName: string }
export interface DirectMessageCandidatePage { candidates: DirectMessageCandidate[]; nextAfter?: string }
export interface OpenedDirectMessage {
  id: string
  participantOneId: string
  participantTwoId: string
  createdAt: string
}

export class DirectMessageCandidateRequestError extends Error {
  constructor(readonly status: number, readonly code?: string) {
    super(`Запрос к личным сообщениям отклонён (${status}).`)
    this.name = 'DirectMessageCandidateRequestError'
  }
}

function invalidPage(): never { throw new Error('Сервер вернул некорректный список участников.') }
function invalidDirectMessage(): never { throw new Error('Сервер вернул некорректный личный диалог.') }
function record(value: unknown): Record<string, unknown> | null { return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null }
function text(value: unknown): string | null { return typeof value === 'string' ? value : null }
function requiredText(value: unknown, invalid: () => never): string { const result = text(value); return result ? result : invalid() }
function optionalText(value: unknown, invalid: () => never): string | undefined { return value === undefined ? undefined : requiredText(value, invalid) }
function date(value: unknown): string { const result = requiredText(value, invalidDirectMessage); return Number.isNaN(Date.parse(result)) ? invalidDirectMessage() : result }

function candidate(value: unknown): DirectMessageCandidate {
  const source = record(value)
  if (!source) invalidPage()
  return { id: requiredText(source.id, invalidPage), displayName: requiredText(source.display_name, invalidPage) }
}

function openedDirectMessage(value: unknown): OpenedDirectMessage {
  const source = record(value)
  if (!source) invalidDirectMessage()
  return {
    id: requiredText(source.id, invalidDirectMessage), participantOneId: requiredText(source.participant_one_id, invalidDirectMessage),
    participantTwoId: requiredText(source.participant_two_id, invalidDirectMessage), createdAt: date(source.created_at),
  }
}

function errorCode(value: unknown): string | undefined {
  const source = record(value)
  const error = source ? record(source.error) : null
  return error ? optionalText(error.code, invalidPage) : undefined
}

async function checked(response: Response): Promise<unknown> {
  let value: unknown
  try { value = await response.json() } catch {
    if (response.ok) invalidPage()
    throw new DirectMessageCandidateRequestError(response.status)
  }
  if (response.ok) return value
  throw new DirectMessageCandidateRequestError(response.status, errorCode(value))
}

function requestInit(method: 'GET' | 'POST', body?: unknown): RequestInit {
  return {
    method,
    credentials: 'same-origin',
    headers: { accept: 'application/json', ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  }
}

export async function loadDirectMessageCandidates(after: string | undefined, request: DirectMessageRequest = fetch): Promise<DirectMessageCandidatePage> {
  const query = after ? `?after=${encodeURIComponent(after)}` : ''
  const source = record(await checked(await request(`${apiBaseUrl}/direct-message-candidates${query}`, requestInit('GET'))))
  if (!source || !Array.isArray(source.candidates)) invalidPage()
  return { candidates: source.candidates.map(candidate), nextAfter: optionalText(source.next_after, invalidPage) }
}

export async function openDirectMessage(participantId: string, request: DirectMessageRequest = fetch): Promise<OpenedDirectMessage> {
  if (!participantId) invalidDirectMessage()
  return openedDirectMessage(await checked(await request(`${apiBaseUrl}/direct-messages`, requestInit('POST', { participant_id: participantId }))))
}
