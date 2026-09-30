import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import type { ProfileRequest } from './profile_client'

export interface AdminAccount { account_id: string; login: string; display_name: string; role: 'MEMBER' | 'ADMINISTRATOR'; blocked: boolean; created_at: string }
export interface AdminAccountPage { accounts: AdminAccount[]; next_cursor?: string }
export interface AuditEvent { id: string; actor_user_id?: string; actor_display_name?: string; actor_login?: string; event_type: string; target_user_id?: string; target_display_name?: string; target_login?: string; created_at: string }
export interface AuditPage { events: AuditEvent[]; next_cursor?: string }
export interface PasswordResetLink { url: string; expires_at: string }
export interface VoiceKickResult { revoked_leases: number }

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('Сервер вернул некорректный ответ администрирования.')
  return value as Record<string, unknown>
}
function text(value: unknown): string { if (typeof value !== 'string') throw new Error('Сервер вернул некорректные данные администрирования.'); return value }
function role(value: unknown): AdminAccount['role'] { if (value === 'MEMBER' || value === 'ADMINISTRATOR') return value; throw new Error('Сервер вернул некорректную роль.') }
function parseAccount(value: unknown): AdminAccount {
  const account = record(value)
  if (typeof account.blocked !== 'boolean') throw new Error('Сервер вернул некорректный статус аккаунта.')
  return { account_id: text(account.account_id), login: text(account.login), display_name: text(account.display_name), role: role(account.role), blocked: account.blocked, created_at: text(account.created_at) }
}
function parseEvent(value: unknown): AuditEvent {
  const event = record(value)
  return {
    id: text(event.id), event_type: text(event.event_type), created_at: text(event.created_at),
    ...(typeof event.actor_user_id === 'string' ? { actor_user_id: event.actor_user_id } : {}),
    ...(typeof event.actor_display_name === 'string' ? { actor_display_name: event.actor_display_name } : {}),
    ...(typeof event.actor_login === 'string' ? { actor_login: event.actor_login } : {}),
    ...(typeof event.target_user_id === 'string' ? { target_user_id: event.target_user_id } : {}),
    ...(typeof event.target_display_name === 'string' ? { target_display_name: event.target_display_name } : {}),
    ...(typeof event.target_login === 'string' ? { target_login: event.target_login } : {}),
  }
}
async function call(path: string, init: RequestInit, request: ProfileRequest): Promise<Response> {
  const response = await request(`${apiBaseUrl}${path}`, { ...init, credentials: 'same-origin', headers: { accept: 'application/json', ...init.headers } })
  if (response.ok) return response
  try { const body = record(await response.json()); const error = record(body.error); if (typeof error.message === 'string') throw new Error(error.message) } catch (cause) { if (cause instanceof Error && cause.message !== 'Сервер вернул некорректный ответ администрирования.') throw cause }
  throw new Error(`Не удалось выполнить запрос (${response.status}).`)
}
function query(cursor: string | undefined): string {
  const parameters = new URLSearchParams({ limit: '100' }); if (cursor) parameters.set('cursor', cursor)
  return parameters.toString()
}
export async function listAdminAccounts(cursor?: string, request: ProfileRequest = tracedFetch): Promise<AdminAccountPage> {
  const page = record(await (await call(`/admin/accounts?${query(cursor)}`, { method: 'GET' }, request)).json())
  if (!Array.isArray(page.accounts)) throw new Error('Сервер вернул некорректный список аккаунтов.')
  return { accounts: page.accounts.map(parseAccount), ...(typeof page.next_cursor === 'string' ? { next_cursor: page.next_cursor } : {}) }
}
export async function listAuditEvents(before?: string, request: ProfileRequest = tracedFetch): Promise<AuditPage> {
  const parameters = new URLSearchParams({ limit: '100' }); if (before) parameters.set('before', before)
  const page = record(await (await call(`/admin/audit?${parameters}`, { method: 'GET' }, request)).json())
  if (!Array.isArray(page.events)) throw new Error('Сервер вернул некорректный список аудита.')
  return { events: page.events.map(parseEvent), ...(typeof page.next_cursor === 'string' ? { next_cursor: page.next_cursor } : {}) }
}
export async function updateAdminAccount(accountID: string, role: AdminAccount['role'], blocked: boolean, request: ProfileRequest = tracedFetch): Promise<void> {
  if (!accountID || !['MEMBER', 'ADMINISTRATOR'].includes(role) || typeof blocked !== 'boolean') throw new Error('Некорректное состояние аккаунта.')
  await call(`/admin/accounts/${encodeURIComponent(accountID)}`, { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ role, blocked }) }, request)
}
export async function createPasswordResetLink(accountID: string, request: ProfileRequest = tracedFetch): Promise<PasswordResetLink> {
  if (!accountID) throw new Error('Не выбран аккаунт для восстановления доступа.')
  const result = record(await (await call('/admin/password-reset-links', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ account_id: accountID }) }, request)).json())
  return { url: text(result.url), expires_at: text(result.expires_at) }
}
export async function kickVoiceParticipant(accountID: string, request: ProfileRequest = tracedFetch): Promise<VoiceKickResult> {
  if (!accountID) throw new Error('Не выбран участник голосового канала.')
  const result = record(await (await call(`/admin/accounts/${encodeURIComponent(accountID)}/voice-kick`, { method: 'POST' }, request)).json())
  if (typeof result.revoked_leases !== 'number' || !Number.isInteger(result.revoked_leases)) throw new Error('Сервер вернул некорректный результат отключения.')
  return { revoked_leases: result.revoked_leases }
}
