import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { MessageRequest } from '../message_client'
export const emojis = ['👍','❤️','😂','🎉','👀','✅'] as const
export type Emoji = typeof emojis[number]
export type ReactionKind = 'CHANNEL' | 'DIRECT_MESSAGE'
export interface Reaction { messageId: string; emoji: Emoji; count: number; mine: boolean }
export interface ReactionPage { rows: Reaction[]; canPin: boolean }
const validID = (value: unknown): value is string => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
function scope(kind: ReactionKind, id: string): string {
  if (!validID(id) || kind !== 'CHANNEL' && kind !== 'DIRECT_MESSAGE') throw new Error('Некорректная беседа.')
  return `${apiBaseUrl}/${kind === 'CHANNEL' ? 'channels' : 'direct-messages'}/${encodeURIComponent(id)}`
}
export async function readReactions(kind: ReactionKind, id: string, ids: string[], request: MessageRequest = tracedFetch): Promise<ReactionPage> {
  const base = scope(kind,id), expected = new Set(ids)
  if (ids.length < 1 || ids.length > 100 || !ids.every(validID)) throw new Error('Некорректные сообщения.')
  const response = await request(`${base}/message-reactions?${new URLSearchParams({message_ids:ids.join(',')})}`, {method:'GET',credentials:'same-origin',headers:{accept:'application/json'}})
  if (!response.ok) throw new Error(`Не удалось получить реакции (${response.status}).`)
  const value = await response.json() as {reactions?: unknown;can_pin?: unknown}
  if (!value || !Array.isArray(value.reactions) || value.reactions.length > 600 || typeof value.can_pin !== 'boolean' || kind === 'DIRECT_MESSAGE' && value.can_pin) throw new Error('Сервер вернул некорректные реакции.')
  const seen = new Set<string>()
  const rows: Reaction[] = value.reactions.map(row => {
    if (!row || !validID(row.message_id) || !expected.has(row.message_id) || !emojis.includes(row.emoji) || !Number.isSafeInteger(row.count) || row.count < 1 || typeof row.mine !== 'boolean' || seen.has(`${row.message_id}:${row.emoji}`)) throw new Error('Сервер вернул некорректные реакции.')
    seen.add(`${row.message_id}:${row.emoji}`)
    return {messageId:row.message_id,emoji:row.emoji,count:row.count,mine:row.mine}
  })
  return {rows,canPin:value.can_pin}
}
export async function setReaction(kind: ReactionKind, id: string, message: string, emoji: Emoji, present: boolean, request: MessageRequest = tracedFetch): Promise<void> {
  const base = scope(kind,id)
  if (!validID(message) || !emojis.includes(emoji) || typeof present !== 'boolean') throw new Error('Некорректная реакция.')
  const response = await request(`${base}/messages/${encodeURIComponent(message)}/reactions/${encodeURIComponent(emoji)}`, {method:present?'PUT':'DELETE',credentials:'same-origin',headers:{accept:'application/json'}})
  if (response.status !== 204) throw new Error(`Не удалось изменить реакцию (${response.status}). Обновите состояние перед повтором.`)
}
