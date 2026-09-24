import { ref } from 'vue'

import type { AdminTopologyRequest } from './admin_topology_client'
import type { TopologyCategory } from './topology_client'
import { closeVoiceAdmission, VoiceCloseError } from './voice_close_client'

export interface VoiceCloseSnapshot { categories: TopologyCategory[]; revision: number; selectedChannelId: string }
export type VoiceClosePhase = 'idle' | 'pending' | 'finalized'

export function createVoiceCloseEditor(snapshot: () => VoiceCloseSnapshot, changed: () => void,
  confirm: (message: string) => boolean, request?: AdminTopologyRequest) {
  const pending = ref(false)
  const needsRefresh = ref(false)
  const error = ref<string | null>(null)
  const status = ref<string | null>(null)
  const phase = ref<VoiceClosePhase>('idle')
  let conflictRevision = -1
  let closingId = ''
  let acceptedRevision = -1

  function selectedVoice() {
    const current = snapshot()
    return current.categories.flatMap(({ channels }) => channels)
      .find(({ id, kind }) => id === current.selectedChannelId && kind === 'VOICE')
  }

  function sync(): void {
    const current = snapshot()
    if (needsRefresh.value && current.revision > conflictRevision) needsRefresh.value = false
    if (closingId && current.revision >= acceptedRevision) {
      const channel = current.categories.flatMap(({ channels }) => channels).find(({ id }) => id === closingId)
      phase.value = channel ? 'pending' : 'finalized'
      status.value = channel ? 'Вход закрыт. Отзыв media-доступа в SFU ещё подтверждается.'
        : 'Удаление голосового канала подтверждено сервером.'
    } else if (!closingId && selectedVoice()?.admissionClosed) {
      phase.value = 'pending'
      status.value = 'Вход закрыт. Отзыв media-доступа в SFU ещё подтверждается.'
    } else if (!closingId && phase.value === 'pending') {
      phase.value = 'idle'
      status.value = null
    }
  }

  async function close(): Promise<boolean> {
    const current = snapshot()
    const channel = selectedVoice()
    if (!channel || channel.admissionClosed || pending.value || needsRefresh.value || current.revision < 1) return false
    if (!confirm(`Закрыть вход в голосовой канал «${channel.name}»? Участникам будет отправлена причина; отзыв media-доступа в SFU может занять время.`)) return false
    error.value = null
    status.value = null
    pending.value = true
    try {
      const result = await closeVoiceAdmission(channel.id, current.revision, request)
      closingId = result.id
      acceptedRevision = result.revision
      conflictRevision = current.revision
      needsRefresh.value = true
      phase.value = 'pending'
      status.value = 'Вход закрыт. Отзыв media-доступа в SFU ещё подтверждается.'
      changed()
      return true
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось закрыть вход в голосовой канал.'
      if (cause instanceof VoiceCloseError && cause.status === 409) {
        conflictRevision = current.revision
        needsRefresh.value = true
        changed()
      }
      return false
    } finally { pending.value = false }
  }

  return { close, error, needsRefresh, pending, phase, status, sync }
}
