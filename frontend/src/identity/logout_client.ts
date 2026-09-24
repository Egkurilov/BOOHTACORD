import { apiBaseUrl } from '../config/runtime'

export type LogoutRequest = (input: string, init: RequestInit) => Promise<Response>

export async function logout(request: LogoutRequest = fetch): Promise<void> {
  let response: Response
  try {
    response = await request(`${apiBaseUrl}/auth/logout`, {
      method: 'POST', credentials: 'same-origin', headers: { accept: 'application/json' },
    })
  } catch {
    throw new Error('Нет связи с сервером. Выход не подтверждён; повторите попытку.')
  }
  if (response.status !== 204) throw new Error(`Сервер не завершил сессию (${response.status}). Повторите попытку.`)
}
