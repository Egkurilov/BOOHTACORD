interface LogMessage {
  id: string
  authorId: string
  createdAt: string
  deleted?: boolean
  sendStatus?: 'sending' | 'checking' | 'failed'
  kind?: string
}

interface LogUpdate {
  conversationId: string
  loaded: boolean
  active: boolean
  ownId: string
  messages: readonly LogMessage[]
  displayName: (authorId: string) => string
}

export function createMessageLogAnnouncer(): (update: LogUpdate) => string | null {
  let conversationId = ''
  let initialized = false
  let latestId: string | undefined
  let latestAt = -Infinity

  return ({ conversationId: target, loaded, active, ownId, messages, displayName }) => {
    if (target !== conversationId) { conversationId = target; initialized = false; latestId = undefined; latestAt = -Infinity }
    if (!loaded) { initialized = false; latestId = undefined; latestAt = -Infinity; return null }
    const server = messages.filter((message) => !message.sendStatus)
    const newest = server[0]
    if (!initialized) { initialized = true; latestId = newest?.id; latestAt = newest ? Date.parse(newest.createdAt) : -Infinity; return null }
    if (!newest || newest.id === latestId) return null
    const newestAt = Date.parse(newest.createdAt)
    if (newestAt < latestAt) return null
    const previousIndex = latestId ? server.findIndex((message) => message.id === latestId) : -1
    if (latestId && previousIndex < 0 && newestAt <= latestAt) return null
    const added = latestId ? previousIndex < 0 ? [newest] : server.slice(0, previousIndex) : server
    latestId = newest.id
    latestAt = newestAt
    if (!active || !ownId) return null
    const incoming = added.filter((message) => message.authorId !== ownId && !message.deleted)
    if (incoming.length === 1) return incoming[0].kind === 'SYSTEM_WELCOME' ? 'Новый участник в гильдии.' : `Новое сообщение от ${displayName(incoming[0].authorId)}.`
    return incoming.length > 1 ? `Новых сообщений: ${incoming.length}.` : null
  }
}
