import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import type { ChannelKind } from './topology_client'

export interface CreateCategoryInput {
  name: string
}

export interface CreatedCategory {
  id: string
  name: string
  position: number
  revision: number
}

export interface CreateChannelInput {
  name: string
  kind: ChannelKind
}

export interface CreatedChannel {
  id: string
  categoryId: string
  name: string
  kind: ChannelKind
  position: number
  revision: number
}

export interface DeletedCategory { id: string; revision: number }

export type AdminTopologyRequest = (input: string, init: RequestInit) => Promise<Response>

function invalidResponse(): never {
  throw new Error('Сервер вернул некорректные данные созданного канала.')
}

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return invalidResponse()
  return value as Record<string, unknown>
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : invalidResponse()
}

function asPosition(value: unknown): number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : invalidResponse()
}

function asKind(value: unknown): ChannelKind {
  return value === 'TEXT' || value === 'VOICE' ? value : invalidResponse()
}

export function parseCreatedCategory(value: unknown): CreatedCategory {
  const category = asRecord(value)
  return {
    id: asString(category.id),
    name: asString(category.name),
    position: asPosition(category.position),
    revision: asPosition(category.revision),
  }
}

export function parseCreatedChannel(value: unknown): CreatedChannel {
  const channel = asRecord(value)
  return {
    id: asString(channel.id),
    categoryId: asString(channel.category_id),
    name: asString(channel.name),
    kind: asKind(channel.kind),
    position: asPosition(channel.position),
    revision: asPosition(channel.revision),
  }
}

async function errorMessage(response: Response): Promise<string> {
  try {
    const source = asRecord(await response.json())
    const error = asRecord(source.error)
    if (typeof error.message === 'string' && error.message.length > 0) return error.message
  } catch {
    // A bounded status message is safe when the server has no valid JSON error body.
  }
  return `Не удалось изменить каналы (${response.status}).`
}

async function post(path: string, input: CreateCategoryInput | CreateChannelInput, request: AdminTopologyRequest): Promise<unknown> {
  const response = await request(`${apiBaseUrl}${path}`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify(input),
  })
  if (!response.ok) throw new Error(await errorMessage(response))
  return response.json()
}

export async function createCategory(input: CreateCategoryInput, request: AdminTopologyRequest = tracedFetch): Promise<CreatedCategory> {
  if (!input.name.trim() || !validCodePointLength(input.name, 1, 80)) throw new Error('Введите имя категории до 80 символов.')
  return parseCreatedCategory(await post('/admin/categories', input, request))
}

export async function createChannel(categoryId: string, input: CreateChannelInput, request: AdminTopologyRequest = tracedFetch): Promise<CreatedChannel> {
  if (!input.name.trim() || !validCodePointLength(input.name, 1, 80)) throw new Error('Введите имя канала до 80 символов.')
  return parseCreatedChannel(await post(`/admin/categories/${encodeURIComponent(categoryId)}/channels`, input, request))
}

export async function deleteEmptyCategory(categoryId: string, expectedRevision: number, request: AdminTopologyRequest = tracedFetch): Promise<DeletedCategory> {
  if (!categoryId || !Number.isInteger(expectedRevision) || expectedRevision < 1) throw new Error('Некорректные параметры удаления категории.')
  const response = await request(`${apiBaseUrl}/admin/categories/${encodeURIComponent(categoryId)}?expected_revision=${expectedRevision}`, { method: 'DELETE', credentials: 'same-origin', headers: { accept: 'application/json' } })
  if (!response.ok) throw new Error(await errorMessage(response))
  const result = asRecord(await response.json())
  return { id: asString(result.id), revision: asPosition(result.revision) }
}
