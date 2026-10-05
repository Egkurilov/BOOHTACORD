import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { ProfileRequest } from '../profile_client'
export interface OwnSession { id: string; label: string; createdAt: string; lastActiveAt: string; current: boolean }
export interface OwnSessionPage { accountId: string; sessions: OwnSession[]; nextCursor: string | null }
export class SessionRequestError extends Error {
  constructor(public readonly status: number, public readonly code: string) {
    super(code === 'SESSION_ACCOUNT_CHANGED' ? 'Аккаунт изменился. Откройте настройки заново.' : `Не удалось обновить сеансы (${status}).`)
  }
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
function handle(value: unknown): string {
  if (typeof value !== 'string' || !uuid.test(value)) throw new Error('Некорректный идентификатор сеанса.')
  return value
}
function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Некорректный список сеансов.')
  return value as Record<string, unknown>
}
function date(value: unknown): string {
  if (typeof value !== 'string' || !Number.isFinite(Date.parse(value))) throw new Error('Некорректная дата сеанса.')
  return value
}
async function call(path: string, init: RequestInit, request: ProfileRequest): Promise<Response> {
  const response = await request(`${apiBaseUrl}/me/sessions${path}`, { ...init, credentials: 'same-origin', cache: 'no-store', headers: { accept: 'application/json', ...init.headers } })
  if (!response.ok) {
    let code = 'REQUEST_FAILED'
    try { const detail = record(record(await response.json()).error); if (typeof detail.code === 'string') code = detail.code } catch { /* Use the status fallback. */ }
    throw new SessionRequestError(response.status, code)
  }
  return response
}
export async function loadOwnSessions(cursor?: string, request: ProfileRequest = tracedFetch): Promise<OwnSessionPage> {
  const body = record(await (await call(cursor ? `?cursor=${handle(cursor)}` : '', { method: 'GET' }, request)).json())
  if (!Array.isArray(body.sessions)) throw new Error('Некорректный список сеансов.')
  const sessions = body.sessions.map(value => {
    const row = record(value)
    if (typeof row.label !== 'string' || typeof row.current !== 'boolean') throw new Error('Некорректный сеанс.')
    return { id: handle(row.id), label: row.label, createdAt: date(row.created_at), lastActiveAt: date(row.last_active_at), current: row.current }
  })
  return { accountId: handle(body.account_id), sessions, nextCursor: body.next_cursor == null ? null : handle(body.next_cursor) }
}
export async function revokeOwnSession(accountId: string, id: string, request: ProfileRequest = tracedFetch): Promise<void> {
  await call(`/${handle(id)}`, { method: 'DELETE', headers: { 'X-Account-ID': handle(accountId) } }, request)
}
export async function revokeOtherSessions(accountId: string, request: ProfileRequest = tracedFetch): Promise<void> {
  await call('/revoke-others', { method: 'POST', headers: { 'X-Account-ID': handle(accountId) } }, request)
}
