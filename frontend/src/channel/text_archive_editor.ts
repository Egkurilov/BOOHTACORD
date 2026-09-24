import { ref } from 'vue'

import type { AdminTopologyRequest } from './admin_topology_client'
import { archiveTextChannel, TextArchiveError } from './text_archive_client'
import type { TopologyCategory } from './topology_client'

export interface TextArchiveSnapshot { categories: TopologyCategory[]; revision: number; selectedChannelId: string }

export function createTextArchiveEditor(snapshot: () => TextArchiveSnapshot, changed: () => void,
  clearSelected: (id: string) => void, confirm: (message: string) => boolean, request?: AdminTopologyRequest) {
  const pending = ref(false)
  const conflict = ref(false)
  const needsRefresh = ref(false)
  const error = ref<string | null>(null)
  const status = ref<string | null>(null)
  let lastRevision = -1
  let lastSelected = ''

  function selectedText() {
    return snapshot().categories.flatMap(({ channels }) => channels)
      .find(({ id, kind }) => id === snapshot().selectedChannelId && kind === 'TEXT')
  }

  function sync(): void {
    const current = snapshot()
    if (current.revision !== lastRevision || current.selectedChannelId !== lastSelected) {
      conflict.value = false
      needsRefresh.value = false
    }
    lastRevision = current.revision
    lastSelected = current.selectedChannelId
  }

  async function archive(): Promise<boolean> {
    const current = snapshot()
    const channel = selectedText()
    if (!channel || pending.value || needsRefresh.value || current.revision < 1) return false
    if (!confirm(`Архивировать текстовый канал «${channel.name}»? История сообщений сохранится, канал исчезнет из навигации.`)) return false
    error.value = null
    status.value = null
    pending.value = true
    try {
      await archiveTextChannel(channel.id, current.revision, request)
      clearSelected(channel.id)
      needsRefresh.value = true
      status.value = 'Канал архивирован. Обновляем список.'
      changed()
      return true
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось архивировать канал.'
      if (cause instanceof TextArchiveError && cause.status === 409) {
        conflict.value = true
        needsRefresh.value = true
        changed()
      }
      return false
    } finally { pending.value = false }
  }

  return { archive, conflict, error, needsRefresh, pending, status, sync }
}
