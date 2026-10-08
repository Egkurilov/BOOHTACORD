export interface HistoryWindowOptions {
  limit?: number
  anchorMessageId?: string
  direction?: 'older' | 'newer'
  canPageOlder?: boolean
  canPageNewer?: boolean
}

export interface BoundedHistoryWindow<T extends { id: string }> {
  messages: T[]
  olderCursor?: string
  newerCursor?: string
}

export function boundHistoryWindow<T extends { id: string }>(
  newestFirst: readonly T[],
  options: HistoryWindowOptions = {},
): BoundedHistoryWindow<T> {
  const limit = options.limit ?? 500
  if (!Number.isInteger(limit) || limit < 1) {
    throw new Error('History window limit must be positive.')
  }

  let start = 0
  if (newestFirst.length > limit) {
    const foundAnchor = newestFirst.findIndex(({ id }) => id === options.anchorMessageId)
    const anchorIndex = Math.max(0, foundAnchor)
    const latestStart = newestFirst.length - limit
    if (options.direction === 'older') {
      start = foundAnchor < 0 ? latestStart : Math.min(anchorIndex, latestStart)
    } else if (options.direction === 'newer') {
      start = foundAnchor < 0 ? 0 : Math.min(Math.max(anchorIndex - limit + 1, 0), latestStart)
    } else {
      start = Math.min(Math.max(anchorIndex - Math.floor(limit / 2), 0), latestStart)
    }
  }

  const end = Math.min(start + limit, newestFirst.length)
  const messages = newestFirst.slice(start, end)
  const canPageNewer = Boolean(options.canPageNewer || start > 0)
  const canPageOlder = Boolean(options.canPageOlder || end < newestFirst.length)
  return {
    messages,
    olderCursor: canPageOlder ? messages.at(-1)?.id : undefined,
    newerCursor: canPageNewer ? messages[0]?.id : undefined,
  }
}
