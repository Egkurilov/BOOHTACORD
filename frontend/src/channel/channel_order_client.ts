import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import type { AdminTopologyRequest } from './admin_topology_client'

export interface ChannelOrderResult { revision: number }

export class ChannelOrderError extends Error {
  constructor(readonly status: number) {
    super(status === 409 ? 'Порядок каналов изменился. Обновите список и повторите действие.'
      : status === 403 ? 'Недостаточно прав для изменения порядка каналов.'
        : `Не удалось изменить порядок каналов (${status}).`)
  }
}

export async function reorderChannels(categoryId: string, ids: string[], expectedRevision: number, request: AdminTopologyRequest = tracedFetch): Promise<ChannelOrderResult> {
  if (!categoryId || !ids.length || ids.some((id) => !id) || new Set(ids).size !== ids.length
    || !Number.isInteger(expectedRevision) || expectedRevision < 1) throw new Error('Некорректный порядок каналов.')
  const response = await request(`${apiBaseUrl}/admin/categories/${encodeURIComponent(categoryId)}/channels/order`, {
    method: 'PUT', credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ expected_revision: expectedRevision, ids }),
  })
  if (!response.ok) throw new ChannelOrderError(response.status)
  const body: unknown = await response.json()
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new Error('Сервер вернул некорректный порядок каналов.')
  const revision = (body as Record<string, unknown>).revision
  if (typeof revision !== 'number' || !Number.isInteger(revision) || revision < 1) throw new Error('Сервер вернул некорректную ревизию каналов.')
  return { revision }
}
