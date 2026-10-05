interface GroupableMessage {
  authorId: string
  createdAt: string
  replyToId?: string
  system?: boolean
  kind?: string
  deleted?: boolean
  sendStatus?: 'sending' | 'checking' | 'failed'
}

export function groupChronologicalMessages<T extends GroupableMessage, E extends { message: T; dateLabel?: string }>(entries: readonly E[]): (E & { grouped: boolean })[] {
  return entries.map((entry, index) => {
    const previous = entries[index - 1]?.message
    const current = entry.message
    const gap = previous ? Date.parse(current.createdAt) - Date.parse(previous.createdAt) : NaN
    const grouped = Boolean(previous && !entry.dateLabel && previous.authorId === current.authorId
      && !previous.replyToId && !current.replyToId && !previous.system && !current.system && previous.kind !== 'SYSTEM_WELCOME' && current.kind !== 'SYSTEM_WELCOME'
      && !previous.deleted && !current.deleted && !previous.sendStatus && !current.sendStatus
      && gap >= 0 && gap <= 5 * 60_000)
    return { ...entry, grouped }
  })
}
