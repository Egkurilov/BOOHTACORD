import { apiBaseUrl } from '../config/runtime'
import { tracedFetch } from '../telemetry/client_tracing'
import { parsePermissionValues, type PermissionValues } from './permission_keys'

export interface PermissionSnapshot { accountId: string; role: 'MEMBER' | 'ADMINISTRATOR'; revision: number; permissions: PermissionValues }
export type PermissionRequest = (input: string, init: RequestInit) => Promise<Response>

export async function loadPermissions(request: PermissionRequest = tracedFetch): Promise<PermissionSnapshot> {
  const response = await request(`${apiBaseUrl}/auth/permissions`, { credentials: 'same-origin', headers: { accept: 'application/json' } })
  if (!response.ok) throw new Error(`Не удалось загрузить разрешения (${response.status}).`)
  const value = await response.json() as Record<string, unknown>
  if (typeof value.account_id !== 'string' || (value.role !== 'MEMBER' && value.role !== 'ADMINISTRATOR') || typeof value.permissions_revision !== 'number' || !Number.isInteger(value.permissions_revision) || value.permissions_revision < 1) throw new Error('Сервер вернул некорректные разрешения.')
  return { accountId: value.account_id, role: value.role, revision: value.permissions_revision, permissions: parsePermissionValues(value.permissions) }
}
