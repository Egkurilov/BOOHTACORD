import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { ProfileRequest } from '../../identity/profile_client'
export interface GuildProfile { name: string; revision: number }
export function validGuildName(value: unknown): value is string {
  return typeof value === 'string' && value === value.trim() && [...value].length >= 1 && [...value].length <= 80 && !/[\p{Cc}\p{Zl}\p{Zp}]/u.test(value)
}
export function parseGuildProfile(value: unknown): GuildProfile {
  const body = value as Partial<GuildProfile> | null
  if (!body || !validGuildName(body.name) || !Number.isSafeInteger(body.revision) || body.revision! < 1) throw new Error('Некорректный профиль гильдии.')
  return { name: body.name, revision: body.revision! }
}
export async function loadGuildProfile(request: ProfileRequest = tracedFetch): Promise<GuildProfile> {
  const response = await request(`${apiBaseUrl}/guild-profile`, { method: 'GET', credentials: 'omit', cache: 'no-store' })
  if (!response.ok) throw new Error('Не удалось загрузить название гильдии.')
  return parseGuildProfile(await response.json())
}
