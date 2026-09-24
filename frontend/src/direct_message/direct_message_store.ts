import { defineStore } from 'pinia'
import { ref } from 'vue'

import {
  loadDirectMessages,
  type DirectMessageListItem,
  type DirectMessageRequest,
} from './direct_message_client'
import { createDirectMessageHistory } from './direct_message_history'
import { createDirectMessageMessageActions } from './direct_message_message_actions'

export const useDirectMessageStore = defineStore('direct-messages', () => {
  const directMessages = ref<DirectMessageListItem[]>([])
  const { close, directMessageId, messages, nextCursor, loadingHistory, olderLoading, historyLoaded, error, olderError, open, refreshHistory, loadOlder } = createDirectMessageHistory()
  const loadingNavigation = ref(false)
  const sending = ref(false)
  let navigationSequence = 0
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

  return {
    close,
    directMessageId,
    directMessages,
    error,
    loadingHistory,
    olderLoading,
    historyLoaded,
    olderError,
    loadOlder,
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
