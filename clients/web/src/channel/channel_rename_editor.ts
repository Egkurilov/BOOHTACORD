import { ref } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'

import type { AdminTopologyRequest } from './admin_topology_client'
import { ChannelRenameError, renameChannel } from './channel_rename_client'
import type { TopologyCategory } from './topology_client'

export interface ChannelRenameSnapshot { categories: TopologyCategory[]; revision: number; selectedChannelId: string }

export function createChannelRenameEditor(snapshot: () => ChannelRenameSnapshot, changed: () => void, request?: AdminTopologyRequest) {
  const draft = ref('')
  const pending = ref(false)
  const conflict = ref(false)
  const needsRefresh = ref(false)
  const error = ref<string | null>(null)
  const status = ref<string | null>(null)
  let selectedId = ''
  let revision = -1
  let dirty = false

  function selectedName(): string {
    return snapshot().categories.flatMap(({ channels }) => channels).find(({ id }) => id === snapshot().selectedChannelId)?.name ?? ''
  }

  function sync(): void {
    const current = snapshot()
    if (current.selectedChannelId !== selectedId) {
      draft.value = selectedName()
      dirty = false
      conflict.value = false
      needsRefresh.value = false
    } else if (current.revision !== revision) {
      conflict.value = false
      needsRefresh.value = false
      if (!dirty) draft.value = selectedName()
    }
    selectedId = current.selectedChannelId
    revision = current.revision
  }

  function setDraft(value: string): void { draft.value = value; dirty = true }

  async function rename(): Promise<boolean> {
    const current = snapshot()
    if (pending.value || needsRefresh.value || !current.selectedChannelId) return false
    error.value = null
    status.value = null
    if (!draft.value.trim() || !validCodePointLength(draft.value, 1, 80)) {
      error.value = 'Введите имя канала до 80 символов.'
      return false
    }
    pending.value = true
    try {
      const result = await renameChannel(current.selectedChannelId, draft.value, current.revision, request)
      if (snapshot().selectedChannelId === current.selectedChannelId) {
        draft.value = result.name
        dirty = false
      }
      needsRefresh.value = true
      status.value = 'Канал переименован. Обновляем список.'
      changed()
      return true
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось переименовать канал.'
      if (cause instanceof ChannelRenameError && cause.status === 409) {
        conflict.value = true
        needsRefresh.value = true
        changed()
      }
      return false
    } finally { pending.value = false }
  }

  return { conflict, draft, error, needsRefresh, pending, rename, setDraft, status, sync }
}
