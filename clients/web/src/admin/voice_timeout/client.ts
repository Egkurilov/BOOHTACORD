import { tracedFetch } from '../../telemetry/client_tracing'
import { apiBaseUrl } from '../../config/runtime'
import type { ProfileRequest } from '../../identity/profile_client'

export const reasons = ['DISRUPTION', 'HARASSMENT', 'SPAM', 'OTHER'] as const
export type Reason = typeof reasons[number]
export type Method = 'GET' | 'PUT' | 'DELETE'
export interface TimeoutInput { expires_at: string; reason_code: Reason }
export interface VoiceTimeoutState {
  active: boolean; expires_at?: string; reason_code?: Reason
  revoked_leases: number; revocation_pending: boolean
}
export class VoiceTimeoutError extends Error {}
function invalid(): never { throw new VoiceTimeoutError('Некорректное состояние ограничения голоса.') }
function parse(raw: unknown): VoiceTimeoutState {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return invalid()
  const value = raw as Record<string, unknown>
  if (typeof value.active !== 'boolean' || typeof value.revocation_pending !== 'boolean' ||
    typeof value.revoked_leases !== 'number' || !Number.isSafeInteger(value.revoked_leases) || value.revoked_leases < 0) return invalid()
  const state: VoiceTimeoutState = { active: value.active, revoked_leases: value.revoked_leases, revocation_pending: value.revocation_pending }
  if (value.active) {
    if (typeof value.expires_at !== 'string' || !/(Z|[+-]\d{2}:\d{2})$/.test(value.expires_at) ||
      !Number.isFinite(Date.parse(value.expires_at)) || !reasons.includes(value.reason_code as Reason)) return invalid()
    state.expires_at = value.expires_at; state.reason_code = value.reason_code as Reason
  } else if (value.expires_at !== undefined || value.reason_code !== undefined) return invalid()
  return state
}
export async function voiceTimeout(account: string, method: Method = 'GET', input?: TimeoutInput,
  signal?: AbortSignal, request: ProfileRequest = tracedFetch): Promise<VoiceTimeoutState> {
  if (!account || (method === 'PUT' && (!input || !reasons.includes(input.reason_code) || !Number.isFinite(Date.parse(input.expires_at))))) return invalid()
  const path = `${method === 'GET' ? '' : '/admin'}/accounts/${encodeURIComponent(account)}/voice-timeout`
  let response: Response
  try {
    response = await request(`${apiBaseUrl}${path}`, { method, signal, credentials: 'same-origin',
      headers: { accept: 'application/json', ...(method === 'PUT' ? { 'content-type': 'application/json' } : {}) },
      ...(method === 'PUT' ? { body: JSON.stringify(input) } : {}) })
  } catch { throw new VoiceTimeoutError('Не удалось связаться с сервером. Обновите состояние.') }
  if (!response.ok) {
    const messages: Record<number, string> = {
      400: 'Срок должен быть в будущем и не превышать 24 часа. Проверьте часы устройства.',
      401: 'Сессия завершена. Войдите снова.', 403: 'Нет прав на управление голосом этого участника.',
      404: 'Участник недоступен.',
    }
    throw new VoiceTimeoutError(messages[response.status] ?? 'Не удалось изменить ограничение. Обновите состояние.')
  }
  try { return parse(await response.json()) } catch { return invalid() }
}
