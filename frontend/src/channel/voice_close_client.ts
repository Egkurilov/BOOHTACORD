import { apiBaseUrl } from '../config/runtime'
import type { AdminTopologyRequest } from './admin_topology_client'

export interface VoiceCloseResult { id: string; revision: number; revokedLeases: number }

export class VoiceCloseError extends Error {
  constructor(readonly status: number) {
    super(status === 409 ? 'Канал или топология изменились. Обновите список и повторите действие.'
      : status === 403 ? 'Недостаточно прав для закрытия голосового канала.'
        : `Не удалось закрыть вход в голосовой канал (${status}).`)
  }
}

export async function closeVoiceAdmission(id: string, expectedRevision: number, request: AdminTopologyRequest = fetch): Promise<VoiceCloseResult> {
  if (!id || !Number.isInteger(expectedRevision) || expectedRevision < 1) throw new Error('Некорректные параметры закрытия канала.')
  const response = await request(`${apiBaseUrl}/admin/voice-channels/${encodeURIComponent(id)}/close-admission`, {
    method: 'POST', credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ expected_revision: expectedRevision }),
  })
  if (!response.ok) throw new VoiceCloseError(response.status)
  const body: unknown = await response.json()
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new Error('Сервер вернул некорректный результат закрытия канала.')
  const result = body as Record<string, unknown>
  if (result.id !== id || typeof result.revision !== 'number' || !Number.isInteger(result.revision) || result.revision < 1
    || typeof result.revoked_leases !== 'number' || !Number.isInteger(result.revoked_leases) || result.revoked_leases < 0) {
    throw new Error('Сервер вернул некорректный результат закрытия канала.')
  }
  return { id, revision: result.revision, revokedLeases: result.revoked_leases }
}
