import { tracedFetch } from '../telemetry/client_tracing'
export interface MaintenanceStatus {
  active: boolean
}

export type MaintenanceRequest = (input: string, init: RequestInit) => Promise<Response>

export async function loadMaintenanceStatus(request: MaintenanceRequest = tracedFetch): Promise<MaintenanceStatus> {
  const response = await request('/api/v1/maintenance', { credentials: 'same-origin', headers: { accept: 'application/json' } })
  if (!response.ok) throw new Error(`Не удалось получить статус обновления (${response.status}).`)
  const source: unknown = await response.json()
  if (typeof source !== 'object' || source === null || Array.isArray(source)) throw new Error('Сервер вернул некорректный статус обновления.')
  const value = source as Record<string, unknown>
  if (typeof value.active !== 'boolean') throw new Error('Сервер вернул некорректный статус обновления.')
  return { active: value.active }
}
