import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import type { AdminTopologyRequest } from './admin_topology_client'

export interface ChannelDescriptionResult { id: string; description: string; revision: number }

export class ChannelDescriptionError extends Error {
  constructor(readonly status: number) {
    super(status === 409 ? 'Канал или топология изменились. Обновите список и повторите действие.'
      : status === 403 ? 'Недостаточно прав для изменения описания канала.'
        : `Не удалось изменить описание канала (${status}).`)
  }
}

export async function updateChannelDescription(
  id: string, description: string, expectedRevision: number, request: AdminTopologyRequest = tracedFetch,
): Promise<ChannelDescriptionResult> {
  if (!id || !validCodePointLength(description, 0, 200) || !Number.isInteger(expectedRevision) || expectedRevision < 1) {
    throw new Error('Введите описание канала до 200 символов и обновите список.')
  }
  const response = await request(`${apiBaseUrl}/admin/channels/${encodeURIComponent(id)}/description`, {
    method: 'PATCH', credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ description, expected_revision: expectedRevision }),
  })
  if (!response.ok) throw new ChannelDescriptionError(response.status)
  const body: unknown = await response.json()
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new Error('Сервер вернул некорректное описание канала.')
  const result = body as Record<string, unknown>
  if (result.id !== id || typeof result.description !== 'string' || !validCodePointLength(result.description, 0, 200)
    || typeof result.revision !== 'number' || !Number.isInteger(result.revision) || result.revision < 1) {
    throw new Error('Сервер вернул некорректное описание канала.')
  }
  return { id, description: result.description, revision: result.revision }
}
