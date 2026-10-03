import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import { parsePermissionValues, type PermissionValues } from '../../authorization/permission_keys'

export type RoleName = 'MEMBER' | 'ADMINISTRATOR'
export interface RolePolicy { role: RoleName; displayName: string; editable: boolean; permissions: PermissionValues }
export interface RolePolicyPage { revision: number; roles: RolePolicy[] }
export type RolePolicyRequest = (input: string, init: RequestInit) => Promise<Response>
export class RolePolicyError extends Error {
  constructor(message: string, readonly status: number, readonly code: string) { super(message) }
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('Сервер вернул некорректные настройки ролей.')
  return value as Record<string, unknown>
}
function parseRole(value: unknown): RolePolicy {
  const source = record(value)
  if ((source.role !== 'MEMBER' && source.role !== 'ADMINISTRATOR') || typeof source.display_name !== 'string' || typeof source.editable !== 'boolean') throw new Error('Сервер вернул некорректную роль.')
  return { role: source.role, displayName: source.display_name, editable: source.editable, permissions: parsePermissionValues(source.permissions) }
}
async function responseError(response: Response): Promise<RolePolicyError> {
  try {
    const body = record(await response.json()); const error = record(body.error)
    if (typeof error.message === 'string' && typeof error.code === 'string') return new RolePolicyError(error.message, response.status, error.code)
  } catch { /* use bounded status fallback */ }
  return new RolePolicyError(`Не удалось изменить настройки ролей (${response.status}).`, response.status, 'REQUEST_FAILED')
}
export async function loadRolePolicies(request: RolePolicyRequest = tracedFetch): Promise<RolePolicyPage> {
  const response = await request(`${apiBaseUrl}/admin/roles`, { method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' } })
  if (!response.ok) throw await responseError(response)
  const source = record(await response.json())
  if (!Number.isInteger(source.revision) || (source.revision as number) < 1 || !Array.isArray(source.roles) || source.roles.length !== 2) throw new Error('Сервер вернул некорректные настройки ролей.')
  return { revision: source.revision as number, roles: source.roles.map(parseRole) }
}
export async function saveMemberPolicy(revision: number, permissions: PermissionValues, confirmDeleteGrants: boolean, request: RolePolicyRequest = tracedFetch): Promise<void> {
  const response = await request(`${apiBaseUrl}/admin/roles/MEMBER/permissions`, { method: 'PUT', credentials: 'same-origin', headers: { accept: 'application/json', 'content-type': 'application/json' }, body: JSON.stringify({ expected_revision: revision, permissions, confirm_delete_grants: confirmDeleteGrants }) })
  if (!response.ok) throw await responseError(response)
}
