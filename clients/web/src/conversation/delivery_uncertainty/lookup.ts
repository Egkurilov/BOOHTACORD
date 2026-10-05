import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import { loadMessagePage, MessageRequestError, type MessageRequest, type TextMessage } from '../message_client'
import { loadDirectMessageHistory, type DirectMessageHistoryItem } from '../../direct_message/direct_message_client'
async function receipt(direct: boolean, conversation: string, client: string, owner: string, request: MessageRequest): Promise<string | null> {
  const path = direct ? 'direct-messages' : 'channels'
  const response = await request(`${apiBaseUrl}/${path}/${encodeURIComponent(conversation)}/message-delivery/${encodeURIComponent(client)}`, { method: 'GET', credentials: 'same-origin', cache: 'no-store', headers: { accept: 'application/json' } })
  if (!response.ok) throw new MessageRequestError(response.status)
  const body = await response.json()
  if (body === null || typeof body !== 'object' || typeof body.account_id !== 'string' || !(body.message_id === null || typeof body.message_id === 'string')) throw new Error('Не удалось подтвердить доставку.')
  if (owner !== 'Вы' && body.account_id !== owner) throw new MessageRequestError(409, 'SESSION_ACCOUNT_CHANGED')
  return body.message_id
}
export async function lookupTextDelivery(conversation: string, client: string, owner: string, request: MessageRequest = tracedFetch): Promise<TextMessage | null> {
  const id = await receipt(false, conversation, client, owner, request)
  if (id === null) return null
  const page = await loadMessagePage(conversation, undefined, request, id)
  const found = page.messages.find(message => message.id === id && message.clientMessageId === client && (owner === 'Вы' || message.authorId === owner))
  if (!found) throw new Error('Сообщение сохранено, но история ещё недоступна. Повторите проверку.')
  return found
}
export async function lookupDirectDelivery(conversation: string, client: string, owner: string, request: MessageRequest = tracedFetch): Promise<DirectMessageHistoryItem | null> {
  const id = await receipt(true, conversation, client, owner, request)
  if (id === null) return null
  const page = await loadDirectMessageHistory(conversation, undefined, request, id)
  const found = page.messages.find(message => message.id === id && message.clientMessageId === client && (owner === 'Вы' || message.authorId === owner))
  if (!found) throw new Error('Сообщение сохранено, но история ещё недоступна. Повторите проверку.')
  return found
}
