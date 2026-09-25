import { apiBaseUrl } from '../config/runtime'
import type { AdminTopologyRequest } from './admin_topology_client'

export interface TextArchiveResult { id: string; revision: number }

export class TextArchiveError extends Error {
  constructor(readonly status: number) {
    super(status === 409 ? 'Канал или топология изменились. Обновите список и повторите действие.'
      : status === 403 ? 'Недостаточно прав для архивации канала.'
        : `Не удалось архивировать канал (${status}).`)
  }
}

export async function archiveTextChannel(id: string, expectedRevision: number, request: AdminTopologyRequest = fetch): Promise<TextArchiveResult> {
  if (!id || !Number.isInteger(expectedRevision) || expectedRevision < 1) throw new Error('Некорректные параметры архивации.')
  const response = await request(`${apiBaseUrl}/admin/channels/${encodeURIComponent(id)}`, {
    method: 'DELETE', credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ expected_revision: expectedRevision, confirm_archive: true }),
  })
  if (!response.ok) throw new TextArchiveError(response.status)
  const body: unknown = await response.json()
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new Error('Сервер вернул некорректную архивацию канала.')
  const result = body as Record<string, unknown>
  if (result.id !== id || typeof result.revision !== 'number' || !Number.isInteger(result.revision) || result.revision < 1) {
    throw new Error('Сервер вернул некорректную архивацию канала.')
  }
  return { id, revision: result.revision }
}
