import { defineStore } from 'pinia'
import { ref } from 'vue'

import {
  loadDirectMessageHistory,
  loadDirectMessages,
  type DirectMessageHistoryItem,
  type DirectMessageListItem,
  type DirectMessageRequest,
} from './direct_message_client'
import { createDirectMessageMessageActions } from './direct_message_message_actions'

export const useDirectMessageStore = defineStore('direct-messages', () => {
  const directMessages = ref<DirectMessageListItem[]>([])
  const directMessageId = ref<string | null>(null)
  const messages = ref<DirectMessageHistoryItem[]>([])
  const nextCursor = ref<string | undefined>()
  const loadingNavigation = ref(false)
  const loadingHistory = ref(false)
  const error = ref<string | null>(null)
  const sending = ref(false)
  let navigationSequence = 0
  let historySequence = 0
  const actions = createDirectMessageMessageActions({ directMessageId, error, messages, sending })

  async function refreshNavigation(request?: DirectMessageRequest): Promise<void> {
    const sequence = ++navigationSequence
    loadingNavigation.value = true
    error.value = null
    try {
      const loaded = await loadDirectMessages(request)
      if (sequence === navigationSequence) directMessages.value = loaded
    } catch (cause) {
      if (sequence === navigationSequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить список личных сообщений.'
    } finally {
      if (sequence === navigationSequence) loadingNavigation.value = false
    }
  }

  async function open(nextDirectMessageId: string, request?: DirectMessageRequest): Promise<void> {
    if (directMessageId.value === nextDirectMessageId) return
    directMessageId.value = nextDirectMessageId
    messages.value = []
    nextCursor.value = undefined
    await refreshHistory(request)
  }

  function close(): void {
    historySequence++
    directMessageId.value = null
    messages.value = []
    nextCursor.value = undefined
    loadingHistory.value = false
    error.value = null
  }

  async function refreshHistory(request?: DirectMessageRequest): Promise<void> {
    const targetDirectMessageId = directMessageId.value
    if (!targetDirectMessageId) return
    const sequence = ++historySequence
    loadingHistory.value = true
    error.value = null
    try {
      const page = await loadDirectMessageHistory(targetDirectMessageId, undefined, request)
      if (directMessageId.value !== targetDirectMessageId || sequence !== historySequence) return
      messages.value = page.messages
      nextCursor.value = page.nextCursor
    } catch (cause) {
      if (directMessageId.value === targetDirectMessageId && sequence === historySequence) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить историю личных сообщений.'
    } finally {
      if (sequence === historySequence) loadingHistory.value = false
    }
  }

  return {
    close,
    directMessageId,
    directMessages,
    error,
    loadingHistory,
    loadingNavigation,
    messages,
    nextCursor,
    open,
    ...actions,
    refreshHistory,
    refreshNavigation,
    sending,
  }
})
