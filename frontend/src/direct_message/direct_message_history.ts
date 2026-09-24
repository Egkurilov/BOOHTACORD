import { ref } from 'vue'

import { loadDirectMessageHistory, type DirectMessageHistoryItem, type DirectMessageRequest } from './direct_message_client'

export function createDirectMessageHistory() {
  const directMessageId = ref<string | null>(null)
  const messages = ref<DirectMessageHistoryItem[]>([])
  const nextCursor = ref<string | undefined>()
  const loadingHistory = ref(false)
  const olderLoading = ref(false)
  const historyLoaded = ref(false)
  const error = ref<string | null>(null)
  const olderError = ref<string | null>(null)
  let generation = 0
  let refreshSequence = 0
  let olderPagesLoaded = false

  function mergePage(incoming: DirectMessageHistoryItem[]): void {
    const byId = new Map(messages.value.map((message) => [message.id, message]))
    for (const message of incoming) {
      const current = byId.get(message.id)
      if (!current || message.revision >= current.revision) byId.set(message.id, message)
    }
    messages.value = [...byId.values()].sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt) || right.id.localeCompare(left.id))
  }

  async function open(nextDirectMessageId: string, request?: DirectMessageRequest): Promise<void> {
    if (directMessageId.value === nextDirectMessageId) return
    generation++
    directMessageId.value = nextDirectMessageId
    messages.value = []
    nextCursor.value = undefined
    olderLoading.value = false
    olderError.value = null
    historyLoaded.value = false
    olderPagesLoaded = false
    await refreshHistory(request)
  }

  function close(): void {
    generation++
    refreshSequence++
    directMessageId.value = null
    messages.value = []
    nextCursor.value = undefined
    loadingHistory.value = false
    olderLoading.value = false
    historyLoaded.value = false
    olderError.value = null
    error.value = null
    olderPagesLoaded = false
  }

  async function refreshHistory(request?: DirectMessageRequest): Promise<void> {
    const target = directMessageId.value
    if (!target) return
    const version = generation
    const sequence = ++refreshSequence
    loadingHistory.value = true
    error.value = null
    try {
      const page = await loadDirectMessageHistory(target, undefined, request)
      if (generation !== version || directMessageId.value !== target || refreshSequence !== sequence) return
      mergePage(page.messages)
      if (!olderPagesLoaded) nextCursor.value = page.nextCursor
      historyLoaded.value = true
    } catch (cause) {
      if (generation === version && refreshSequence === sequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить историю личных сообщений.'
    } finally {
      if (generation === version && refreshSequence === sequence) loadingHistory.value = false
    }
  }

  async function loadOlder(request?: DirectMessageRequest): Promise<boolean> {
    const target = directMessageId.value
    const before = nextCursor.value
    if (!target || !historyLoaded.value || !before || olderLoading.value) return false
    const version = generation
    olderLoading.value = true
    olderError.value = null
    try {
      const page = await loadDirectMessageHistory(target, before, request)
      if (generation !== version || directMessageId.value !== target) return false
      mergePage(page.messages)
      nextCursor.value = page.nextCursor
      olderPagesLoaded = true
      return true
    } catch (cause) {
      if (generation === version) olderError.value = cause instanceof Error ? cause.message : 'Не удалось загрузить старые личные сообщения.'
      return false
    } finally {
      if (generation === version) olderLoading.value = false
    }
  }

  return { close, directMessageId, messages, nextCursor, loadingHistory, olderLoading, historyLoaded, error, olderError, open, refreshHistory, loadOlder }
}
