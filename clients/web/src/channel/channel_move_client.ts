import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import type { AdminTopologyRequest } from './admin_topology_client'

export interface ChannelMoveResult { id: string; categoryId: string; position: number; revision: number }

export class ChannelMoveError extends Error {
  constructor(readonly status: number) {
    super(status === 409 ? 'Топология изменилась. Обновите список и повторите перенос.'
      : status === 403 ? 'Недостаточно прав для переноса канала.'
        : `Не удалось перенести канал (${status}).`)
  }
}

export async function moveChannel(id: string, categoryId: string, expectedRevision: number, request: AdminTopologyRequest = tracedFetch): Promise<ChannelMoveResult> {
  if (!id || !categoryId || !Number.isInteger(expectedRevision) || expectedRevision < 1) throw new Error('Некорректные параметры переноса канала.')
  const response = await request(`${apiBaseUrl}/admin/channels/${encodeURIComponent(id)}/category`, {
    method: 'PATCH', credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ category_id: categoryId, expected_revision: expectedRevision }),
  })
  if (!response.ok) throw new ChannelMoveError(response.status)
  const body: unknown = await response.json()
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new Error('Сервер вернул некорректный перенос канала.')
  const result = body as Record<string, unknown>
  if (result.id !== id || result.category_id !== categoryId || typeof result.position !== 'number'
    || !Number.isInteger(result.position) || result.position < 0 || typeof result.revision !== 'number'
    || !Number.isInteger(result.revision) || result.revision < 1) throw new Error('Сервер вернул некорректный перенос канала.')
  return { id, categoryId, position: result.position, revision: result.revision }
}
