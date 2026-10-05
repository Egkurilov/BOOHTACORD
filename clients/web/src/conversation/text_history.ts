import { ref } from 'vue'

import { loadMessagePage, type MessageRequest, type TextMessage, type TextMessageAttachment } from './message_client'
import { findLoadedMessage } from './message_revision_refresh'

export interface PendingSend { retryBlocked?: boolean; channelId: string; authorId: string; body: string; replyToId?: string; attachments: TextMessageAttachment[]; mentionUserIds: string[]; request?: MessageRequest; sendStatus?: 'sending' | 'checking' | 'failed' }

export function pendingMessage(id: string, draft: PendingSend): TextMessage {
  return { id: `optimistic:${id}`, channelId: draft.channelId, authorId: draft.authorId, clientMessageId: id, body: draft.body, replyToId: draft.replyToId, revision: 0, createdAt: new Date().toISOString(), deleted: false, attachments: draft.attachments, mentionUserIds: draft.mentionUserIds, retryBlocked: draft.retryBlocked, sendStatus: draft.sendStatus ?? 'failed' }
}

export function createTextHistory(pending: Map<string, PendingSend>) {
  const channelId = ref<string | null>(null)
  const messages = ref<TextMessage[]>([])
  const nextCursor = ref<string | undefined>()
  const loading = ref(false)
  const olderLoading = ref(false)
  const historyLoaded = ref(false)
  const error = ref<string | null>(null)
  const olderError = ref<string | null>(null)
  let generation = 0
  let refreshSequence = 0
  let olderPagesLoaded = false

  function mergePage(incoming: TextMessage[]): void {
    const byId = new Map<string, TextMessage>()
    for (const message of messages.value) if (!message.sendStatus) byId.set(message.id, message)
    for (const message of incoming) {
      const current = byId.get(message.id)
      if (!current || message.revision >= current.revision) byId.set(message.id, message)
    }
    const server = [...byId.values()].sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt) || right.id.localeCompare(left.id))
    const acknowledged = new Set(server.map(({ clientMessageId }) => clientMessageId))
    const queued = [...pending].flatMap(([id, draft]) => {
      if (draft.channelId !== channelId.value) return []
      if (acknowledged.has(id)) { pending.delete(id); return [] }
      return [pendingMessage(id, draft)]
    })
    messages.value = [...queued, ...server]
  }

  async function open(nextChannelId: string, request?: MessageRequest): Promise<void> {
    if (channelId.value === nextChannelId) return
    generation++
    channelId.value = nextChannelId
    messages.value = []
    nextCursor.value = undefined
    olderLoading.value = false
    olderError.value = null
    historyLoaded.value = false
    olderPagesLoaded = false
    await refresh(request)
  }

  async function refresh(request?: MessageRequest): Promise<void> {
    const target = channelId.value
    if (!target) return
    const version = generation
    const sequence = ++refreshSequence
    loading.value = true
    error.value = null
    try {
      const page = await loadMessagePage(target, undefined, request)
      if (generation !== version || channelId.value !== target || refreshSequence !== sequence) return
      mergePage(page.messages)
      if (!olderPagesLoaded) nextCursor.value = page.nextCursor
      historyLoaded.value = true
    } catch (cause) {
      if (generation === version && refreshSequence === sequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить историю сообщений.'
    } finally {
      if (generation === version && refreshSequence === sequence) loading.value = false
    }
  }

  async function loadOlder(request?: MessageRequest): Promise<boolean> {
    const target = channelId.value
    const before = nextCursor.value
    if (!target || !historyLoaded.value || !before || olderLoading.value) return false
    const version = generation
    olderLoading.value = true
    olderError.value = null
    try {
      const page = await loadMessagePage(target, before, request)
      if (generation !== version || channelId.value !== target) return false
      mergePage(page.messages)
      nextCursor.value = page.nextCursor
      olderPagesLoaded = true
      return true
    } catch (cause) {
      if (generation === version) olderError.value = cause instanceof Error ? cause.message : 'Не удалось загрузить старые сообщения.'
      return false
    } finally {
      if (generation === version) olderLoading.value = false
    }
  }

  async function refreshMessage(messageId: string, request?: MessageRequest): Promise<TextMessage | null> {
    const target = channelId.value
    const version = generation
    if (!target || !messages.value.some(({ id }) => id === messageId)) return null
    try {
      const count = messages.value.filter(({ sendStatus }) => !sendStatus).length
      const found = await findLoadedMessage(messageId, count, (before) => loadMessagePage(target, before, request), () => generation === version && channelId.value === target)
      if (found) mergePage([found])
      return found ? messages.value.find(({ id }) => id === messageId) ?? null : null
    } catch (cause) {
      if (generation === version) error.value = cause instanceof Error ? cause.message : 'Не удалось обновить сообщение.'
      return null
    }
  }

  return { channelId, messages, nextCursor, loading, olderLoading, historyLoaded, error, olderError, open, refresh, loadOlder, refreshMessage }
}
