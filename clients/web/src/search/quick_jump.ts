export interface QuickJumpChannel { id: string; name: string; kind: 'TEXT' | 'VOICE' }
export interface QuickJumpPerson { id: string; displayName: string; kind?: 'DIRECT_MESSAGE' | 'MEMBER' }
export interface QuickJumpTarget { kind: 'CHANNEL' | 'DIRECT_MESSAGE' | 'MEMBER'; id: string }
export interface QuickJumpEntry {
  kind: QuickJumpTarget['kind']
  id: QuickJumpTarget['id']
  title: string
  subtitle: string
}

export function buildQuickJumpEntries(query: string, channels: readonly QuickJumpChannel[], people: readonly QuickJumpPerson[]): QuickJumpEntry[] {
  const needle = query.trim().toLowerCase()
  const matches = (value: string) => !needle || value.toLowerCase().includes(needle)
  const rooms = channels.filter((channel) => channel.kind === 'TEXT' && matches(channel.name)).map((channel) => ({
    kind: 'CHANNEL' as const, id: channel.id, title: `#${channel.name}`, subtitle: 'Текстовый канал',
  }))
  const directMessages = people.filter((person) => matches(person.displayName)).map((person) => ({
    kind: person.kind ?? 'DIRECT_MESSAGE' as const, id: person.id, title: person.displayName,
    subtitle: person.kind === 'MEMBER' ? 'Участник гильдии' : 'Личное сообщение',
  }))
  return [...rooms, ...directMessages].slice(0, 30)
}
