import { computed, ref } from 'vue'

import { loadMessagePage, type MessageRequest, type TextMessage } from './message_client'
import { createLoadedRevisionRefresh } from './revision_refresh/loaded'
import { indexMessages } from './message_index/index'
import { boundHistoryWindow } from './history_window/eviction'
import { createHistoryMerger } from './history_window/merge'
import { createHistoryPaging } from './history_window/paging'
import { type PendingSend } from './history_window/pending'

export { pendingMessage, type PendingSend } from './history_window/pending'

export function createTextHistory(pending: Map<string, PendingSend>) {
  const channelId = ref<string | null>(null)
  const messages = ref<TextMessage[]>([])
  const messageById = computed(() => indexMessages(messages.value))
  const nextCursor = ref<string | undefined>()
  const newerCursor = ref<string | undefined>()
  const loading = ref(false)
  const olderLoading = ref(false)
  const newerLoading = ref(false)
  const historyLoaded = ref(false)
  const error = ref<string | null>(null)
  const olderError = ref<string | null>(null)
  const newerError = ref<string | null>(null)
  const historyAnchorId = ref<string | undefined>()
  let generation = 0
  let refreshSequence = 0
  let windowPaged = false
  const mergePage = createHistoryMerger(messages, channelId, pending)

  function applyWindow(canPageOlder: boolean, canPageNewer: boolean, direction?: 'older' | 'newer'): void {
    const optimistic = messages.value.filter((message) => message.sendStatus)
    const bounded = boundHistoryWindow(
      messages.value.filter((message) => !message.sendStatus),
      { anchorMessageId: historyAnchorId.value, direction, canPageOlder, canPageNewer },
    )
    nextCursor.value = bounded.olderCursor
    newerCursor.value = bounded.newerCursor
    messages.value = [...optimistic, ...bounded.messages]
  }
  const paging = createHistoryPaging({
    channelId, historyLoaded, olderCursor: nextCursor, newerCursor,
    olderLoading, newerLoading, olderError, newerError,
    generation: () => generation, merge: mergePage, applyWindow,
    markPaged: () => { windowPaged = true },
  })

  async function open(nextChannelId: string, request?: MessageRequest): Promise<void> {
    if (channelId.value === nextChannelId) return
    generation++
    channelId.value = nextChannelId
    messages.value = []
    nextCursor.value = undefined
    newerCursor.value = undefined
    olderLoading.value = false
    newerLoading.value = false
    olderError.value = null
    newerError.value = null
    historyAnchorId.value = undefined
    historyLoaded.value = false
    windowPaged = false
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
      applyWindow(
        windowPaged ? Boolean(nextCursor.value) : Boolean(page.nextCursor),
        windowPaged && Boolean(newerCursor.value),
      )
      historyLoaded.value = true
    } catch (cause) {
      if (generation === version && refreshSequence === sequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить историю сообщений.'
    } finally {
      if (generation === version && refreshSequence === sequence) loading.value = false
    }
  }

  const { refreshMessage, refreshMessages } = createLoadedRevisionRefresh<TextMessage, MessageRequest>({ messages,
    resourceId: channelId, version: () => generation, load: loadMessagePage,
    merge: (incoming) => { mergePage(incoming); applyWindow(Boolean(nextCursor.value), Boolean(newerCursor.value)) }, error,
    fallback: 'Не удалось обновить сообщение.' })

  return { channelId, messages, messageById, nextCursor, newerCursor, loading, olderLoading, newerLoading, historyLoaded, error, olderError, newerError, open, refresh, ...paging, setHistoryAnchor: (id?: string) => { historyAnchorId.value = id }, refreshMessage, refreshMessages }
}
