import { apiBaseUrl } from '../config/runtime'

export type ChannelKind = 'TEXT' | 'VOICE'

export interface TopologyChannel {
  id: string
  name: string
  kind: ChannelKind
  position: number
  admissionClosed: boolean
  unreadCount?: number
  mentionCount?: number
  firstUnreadMessageId?: string
}

export interface TopologyCategory {
  id: string
  name: string
  position: number
  channels: TopologyChannel[]
}

export interface ChannelTopology {
  revision: number
  categories: TopologyCategory[]
}

export type TopologyRequest = (input: string, init: RequestInit) => Promise<Response>

function invalidTopology(): never {
  throw new Error('Сервер вернул некорректную топологию каналов.')
}

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return invalidTopology()
  }

  return value as Record<string, unknown>
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : invalidTopology()
}

function asPosition(value: unknown): number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0
    ? value
    : invalidTopology()
}

function asKind(value: unknown): ChannelKind {
  return value === 'TEXT' || value === 'VOICE' ? value : invalidTopology()
}

function readChannel(value: unknown): TopologyChannel {
  const channel = asRecord(value)
  const kind = asKind(channel.kind)
  if (typeof channel.admission_closed !== 'boolean') {
    return invalidTopology()
  }

  return {
    id: asString(channel.id),
    name: asString(channel.name),
    kind,
    position: asPosition(channel.position),
    admissionClosed: channel.admission_closed,
    ...(kind === 'TEXT' ? { unreadCount: asPosition(channel.unread_count), mentionCount: asPosition(channel.mention_count),
      ...(typeof channel.first_unread_message_id === 'string' && channel.first_unread_message_id ? { firstUnreadMessageId: channel.first_unread_message_id } : {}) } : {}),
  }
}

function readCategory(value: unknown): TopologyCategory {
  const category = asRecord(value)
  if (!Array.isArray(category.channels)) {
    return invalidTopology()
  }

  return {
    id: asString(category.id),
    name: asString(category.name),
    position: asPosition(category.position),
    channels: category.channels.map(readChannel),
  }
}

export function parseTopology(value: unknown): ChannelTopology {
  const topology = asRecord(value)
  if (!Array.isArray(topology.categories)) {
    return invalidTopology()
  }

  return {
    revision: asPosition(topology.revision),
    categories: topology.categories.map(readCategory),
  }
}

export async function loadTopology(request: TopologyRequest = fetch): Promise<ChannelTopology> {
  const response = await request(`${apiBaseUrl}/channels`, {
    credentials: 'same-origin',
    headers: { accept: 'application/json' },
  })
  if (!response.ok) {
    throw new Error(`Не удалось получить каналы (${response.status}).`)
  }

  return parseTopology(await response.json())
}
