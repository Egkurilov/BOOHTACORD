interface UnreadChannel { id: string; kind: string; unreadCount?: number }
interface UnreadTopology { categories: { channels: UnreadChannel[] }[] }
interface UnreadDirectMessage { id: string; unreadCount: number }
interface EventHint { kind: string; payload: Record<string, unknown> }

export function unreadTotal(topology: UnreadTopology | null, directMessages: UnreadDirectMessage[]): number {
  const channels = topology?.categories.flatMap(({ channels }) => channels) ?? []
  return channels.reduce((count, item) => count + (item.kind === 'TEXT' ? item.unreadCount ?? 0 : 0), 0)
    + directMessages.reduce((count, item) => count + item.unreadCount, 0)
}

export function notificationTitle(base: string, count: number): string {
  return count > 0 ? `(${count > 99 ? '99+' : count}) ${base}` : base
}

export function addressedUnread(event: EventHint, topology: UnreadTopology | null, directMessages: UnreadDirectMessage[]): number | null {
  if (event.kind === 'direct_message.message_created') {
    const id = event.payload.direct_message_id
    return directMessages.find((item) => item.id === id)?.unreadCount ?? null
  }
  if (event.kind === 'message.created') {
    const id = event.payload.channel_id
    return topology?.categories.flatMap(({ channels }) => channels).find((item) => item.id === id && item.kind === 'TEXT')?.unreadCount ?? null
  }
  return null
}

export function notificationCandidate(event: EventHint, topology: UnreadTopology | null, directMessages: UnreadDirectMessage[], previousUnread = 0): string | null {
  const current = addressedUnread(event, topology, directMessages)
  if (current === null || current <= previousUnread) return null
  return event.kind === 'direct_message.message_created' ? 'Новое личное сообщение.' : 'Новое сообщение в канале.'
}
