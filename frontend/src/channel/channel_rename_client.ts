import { apiBaseUrl } from '../config/runtime'
import type { AdminTopologyRequest } from './admin_topology_client'

export interface ChannelRenameResult { id: string; name: string; revision: number }

export class ChannelRenameError extends Error {
  constructor(readonly status: number) {
    super(status === 409 ? 'Канал или топология изменились. Обновите список и повторите действие.'
      : status === 403 ? 'Недостаточно прав для переименования канала.'
        : `Не удалось переименовать канал (${status}).`)
  }
}

export async function renameChannel(id: string, name: string, expectedRevision: number, request: AdminTopologyRequest = fetch): Promise<ChannelRenameResult> {
  if (!id || !name.trim() || Array.from(name).length > 80 || !Number.isInteger(expectedRevision) || expectedRevision < 1) {
    throw new Error('Введите имя канала до 80 символов и обновите список.')
  }
  const response = await request(`${apiBaseUrl}/admin/channels/${encodeURIComponent(id)}`, {
    method: 'PATCH', credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ name, expected_revision: expectedRevision }),
  })
  if (!response.ok) throw new ChannelRenameError(response.status)
  const body: unknown = await response.json()
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new Error('Сервер вернул некорректный канал.')
  const result = body as Record<string, unknown>
  if (result.id !== id || typeof result.name !== 'string' || !result.name || typeof result.revision !== 'number'
    || !Number.isInteger(result.revision) || result.revision < 1) throw new Error('Сервер вернул некорректный канал.')
  return { id, name: result.name, revision: result.revision }
}
