import { apiBaseUrl } from '../../config/runtime'
import type { ScreenShareDescriptorV1 } from './types'

export type ScreenProfileDescriptorRequest = (input: string, init: RequestInit) => Promise<Response>

export async function updateScreenProfileDescriptor(leaseId: string, descriptor: ScreenShareDescriptorV1, request: ScreenProfileDescriptorRequest = fetch): Promise<void> {
  const input = `${apiBaseUrl}/voice/leases/${encodeURIComponent(leaseId)}/screen-profile/v1`
  const init: RequestInit = {
    method: 'PUT', mode: 'same-origin', redirect: 'error', referrerPolicy: 'no-referrer', credentials: 'same-origin', cache: 'no-store',
    headers: { accept: 'application/json', 'content-type': 'application/json' }, body: JSON.stringify(descriptor),
  }
  let response: Response | undefined
  for (let attempt = 0; attempt < 2; attempt++) {
    try { response = await request(input, init) }
    catch (error) { if (attempt === 1) throw error; continue }
    if (response.ok) return
    if (response.status < 500 || attempt === 1) throw new Error('Не удалось обновить профиль демонстрации экрана.')
  }
  throw new Error('Не удалось обновить профиль демонстрации экрана.')
}
