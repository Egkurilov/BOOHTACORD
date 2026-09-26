import { apiBaseUrl } from '../config/runtime'

export interface VoiceRosterMember {
  accountId: string
  displayName: string
  screenSharing: boolean
}

export interface VoiceRoomRoster {
  channelId: string
  participants: VoiceRosterMember[]
}

export type VoiceRosterRequest = (input: string, init: RequestInit) => Promise<Response>

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Некорректный состав голосовых каналов.')
  return value as Record<string, unknown>
}

function nonempty(value: unknown): string {
  if (typeof value !== 'string' || !value.trim()) throw new Error('Некорректный состав голосовых каналов.')
  return value
}

export function parseVoiceRosters(value: unknown): VoiceRoomRoster[] {
  const channels = record(value).channels
  if (!Array.isArray(channels)) throw new Error('Некорректный состав голосовых каналов.')
  const seen = new Set<string>()
  return channels.map((item): VoiceRoomRoster => {
    const channel = record(item)
    const channelId = nonempty(channel.channel_id)
    if (seen.has(channelId) || !Array.isArray(channel.participants)) throw new Error('Некорректный состав голосовых каналов.')
    seen.add(channelId)
    const members = new Set<string>()
    const participants = channel.participants.map((entry): VoiceRosterMember => {
      const member = record(entry)
      const accountId = nonempty(member.account_id)
      if (members.has(accountId) || typeof member.screen_sharing !== 'boolean') throw new Error('Некорректный состав голосовых каналов.')
      members.add(accountId)
      return { accountId, displayName: nonempty(member.display_name), screenSharing: member.screen_sharing }
    })
    return { channelId, participants }
  })
}

export async function loadVoiceRosters(request: VoiceRosterRequest = fetch): Promise<VoiceRoomRoster[]> {
  const response = await request(`${apiBaseUrl}/voice/participants`, {
    credentials: 'same-origin', cache: 'no-store', headers: { accept: 'application/json' },
  })
  if (!response.ok) throw new Error(`Не удалось обновить состав голосовых каналов (${response.status}).`)
  return parseVoiceRosters(await response.json())
}
