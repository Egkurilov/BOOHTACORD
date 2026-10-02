import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import type { AdminTopologyRequest } from './admin_topology_client'

export interface CategoryRenameResult { id: string; name: string; revision: number }
export interface CategoryRevision { revision: number }

export class CategoryMutationError extends Error {
  constructor(readonly status: number) {
    super(status === 409 ? 'Категории изменились. Обновите список и повторите действие.'
      : status === 403 ? 'Недостаточно прав для изменения категорий.'
        : `Не удалось изменить категории (${status}).`)
  }
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('Сервер вернул некорректные данные категории.')
  return value as Record<string, unknown>
}

function revision(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 1) throw new Error('Сервер вернул некорректную ревизию категорий.')
  return value
}

function expectedRevision(value: number): void {
  if (!Number.isInteger(value) || value < 1) throw new Error('Некорректная ревизия категорий.')
}

async function mutate(path: string, method: 'PATCH' | 'PUT', body: unknown, request: AdminTopologyRequest): Promise<Record<string, unknown>> {
  const response = await request(`${apiBaseUrl}${path}`, {
    method, credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!response.ok) throw new CategoryMutationError(response.status)
  return record(await response.json())
}

export async function renameCategory(id: string, name: string, expected: number, request: AdminTopologyRequest = tracedFetch): Promise<CategoryRenameResult> {
  expectedRevision(expected)
  if (!id || !name.trim() || !validCodePointLength(name, 1, 80)) throw new Error('Введите имя категории до 80 символов.')
  const result = await mutate(`/admin/categories/${encodeURIComponent(id)}`, 'PATCH', { name, expected_revision: expected }, request)
  if (typeof result.id !== 'string' || result.id !== id || typeof result.name !== 'string' || !result.name) throw new Error('Сервер вернул некорректные данные категории.')
  return { id: result.id, name: result.name, revision: revision(result.revision) }
}

export async function reorderCategories(ids: string[], expected: number, request: AdminTopologyRequest = tracedFetch): Promise<CategoryRevision> {
  expectedRevision(expected)
  if (!ids.length || ids.some((id) => !id) || new Set(ids).size !== ids.length) throw new Error('Некорректный порядок категорий.')
  const result = await mutate('/admin/categories/order', 'PUT', { expected_revision: expected, ids }, request)
  return { revision: revision(result.revision) }
}
