import type { Ref } from 'vue'
import { requestFailureMessage } from '../../request_feedback'

import { loadMessagePage, type MessageRequest, type TextMessage } from '../message_client'

interface PagingState {
  channelId: Ref<string | null>
  historyLoaded: Ref<boolean>
  olderCursor: Ref<string | undefined>
  newerCursor: Ref<string | undefined>
  olderLoading: Ref<boolean>
  newerLoading: Ref<boolean>
  olderError: Ref<string | null>
  newerError: Ref<string | null>
  generation: () => number
  merge: (messages: TextMessage[]) => void
  applyWindow: (canPageOlder: boolean, canPageNewer: boolean, direction?: 'older' | 'newer') => void
  markPaged: () => void
}

export function createHistoryPaging(state: PagingState) {
  async function loadOlder(request?: MessageRequest): Promise<boolean> {
    const channel = state.channelId.value, before = state.olderCursor.value
    if (!channel || !state.historyLoaded.value || !before || state.olderLoading.value) return false
    const generation = state.generation()
    state.olderLoading.value = true
    state.olderError.value = null
    try {
      const page = await loadMessagePage(channel, before, request)
      if (generation !== state.generation() || channel !== state.channelId.value) return false
      state.merge(page.messages)
      state.markPaged()
      state.applyWindow(Boolean(page.nextCursor), Boolean(state.newerCursor.value), 'older')
      return true
    } catch (cause) {
      if (generation === state.generation()) state.olderError.value = requestFailureMessage(cause, 'Не удалось загрузить старые сообщения.')
      return false
    } finally {
      if (generation === state.generation()) state.olderLoading.value = false
    }
  }

  async function loadNewer(request?: MessageRequest): Promise<boolean> {
    const channel = state.channelId.value, after = state.newerCursor.value
    if (!channel || !state.historyLoaded.value || !after || state.newerLoading.value) return false
    const generation = state.generation()
    state.newerLoading.value = true
    state.newerError.value = null
    try {
      const page = await loadMessagePage(channel, undefined, request, undefined, after)
      if (generation !== state.generation() || channel !== state.channelId.value) return false
      state.merge(page.messages)
      state.markPaged()
      state.applyWindow(Boolean(state.olderCursor.value), Boolean(page.nextCursor), 'newer')
      return true
    } catch (cause) {
      if (generation === state.generation()) state.newerError.value = requestFailureMessage(cause, 'Не удалось загрузить новые сообщения.')
      return false
    } finally {
      if (generation === state.generation()) state.newerLoading.value = false
    }
  }

  return { loadOlder, loadNewer }
}
