import { defineStore } from 'pinia'
import { ref } from 'vue'

import {
  DirectMessageCandidateRequestError,
  loadDirectMessageCandidates,
  openDirectMessage,
  type DirectMessageCandidate,
} from './direct_message_candidate_client'
import type { DirectMessageRequest } from './direct_message_client'

const unavailableParticipantMessage = 'Участник больше недоступен. Обновите список.'
const loadFailureMessage = 'Не удалось загрузить участников. Повторите попытку.'
const openFailureMessage = 'Не удалось открыть личный диалог. Повторите попытку.'

export const useDirectMessageCandidateStore = defineStore('direct-message-candidates', () => {
  const candidates = ref<DirectMessageCandidate[]>([])
  const nextAfter = ref<string | undefined>()
  const loading = ref(false)
  const opening = ref(false)
  const error = ref<string | null>(null)
  let sequence = 0

  async function load(after: string | undefined, replace: boolean, request?: DirectMessageRequest): Promise<void> {
    const requestSequence = ++sequence
    loading.value = true
    error.value = null
    try {
      const page = await loadDirectMessageCandidates(after, request)
      if (requestSequence !== sequence) return
      candidates.value = replace ? page.candidates : [...candidates.value, ...page.candidates.filter((item) => !candidates.value.some((current) => current.id === item.id))]
      nextAfter.value = page.nextAfter
    } catch {
      if (requestSequence === sequence) error.value = loadFailureMessage
    } finally {
      if (requestSequence === sequence) loading.value = false
    }
  }

  async function refresh(request?: DirectMessageRequest): Promise<void> { await load(undefined, true, request) }

  async function loadNext(request?: DirectMessageRequest): Promise<void> {
    if (!nextAfter.value || loading.value) return
    await load(nextAfter.value, false, request)
  }

  async function open(participantId: string, request?: DirectMessageRequest): Promise<string | null> {
    if (opening.value) return null
    opening.value = true
    error.value = null
    try {
      return (await openDirectMessage(participantId, request)).id
    } catch (cause) {
      error.value = cause instanceof DirectMessageCandidateRequestError && cause.status === 404 && cause.code === 'NOT_FOUND'
        ? unavailableParticipantMessage : openFailureMessage
      return null
    } finally {
      opening.value = false
    }
  }

  return { candidates, error, loadNext, loading, nextAfter, open, opening, refresh }
})
