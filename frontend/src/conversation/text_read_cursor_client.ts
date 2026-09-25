import { apiBaseUrl } from '../config/runtime'
import type { MessageRequest } from './message_client'

export interface TextReadCursor { channelId: string; messageId: string; messageCreatedAt: string }

export async function advanceTextReadCursor(channelId: string, messageId: string, request: MessageRequest = fetch): Promise<TextReadCursor> {
  if (!channelId || !messageId) throw new Error('Некорректный курсор чтения.')
  const response = await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/read-cursor`, {
    method: 'PUT', credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ message_id: messageId }),
  })
  if (!response.ok) throw new Error(`Не удалось обновить курсор чтения (${response.status}).`)
  const body: unknown = await response.json()
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new Error('Сервер вернул некорректный курсор чтения.')
  const value = body as Record<string, unknown>
  if (value.channel_id !== channelId || typeof value.message_id !== 'string' || !value.message_id
    || typeof value.message_created_at !== 'string' || Number.isNaN(Date.parse(value.message_created_at))) {
    throw new Error('Сервер вернул некорректный курсор чтения.')
  }
  return { channelId, messageId: value.message_id, messageCreatedAt: value.message_created_at }
}
