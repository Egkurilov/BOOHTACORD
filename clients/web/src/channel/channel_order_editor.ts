import { ref } from 'vue'

import type { AdminTopologyRequest } from './admin_topology_client'
import { ChannelOrderError, reorderChannels } from './channel_order_client'
import type { TopologyCategory } from './topology_client'

export interface ChannelOrderSnapshot { categories: TopologyCategory[]; revision: number; selectedCategoryId: string; selectedChannelId: string }

export function createChannelOrderEditor(snapshot: () => ChannelOrderSnapshot, changed: () => void, request?: AdminTopologyRequest) {
  const pending = ref(false)
  const conflict = ref(false)
  const needsRefresh = ref(false)
  const error = ref<string | null>(null)
  const status = ref<string | null>(null)
  let lastRevision = -1
  let lastCategoryId = ''

  function currentCategory(): TopologyCategory | undefined {
    const current = snapshot()
    return current.categories.find(({ id }) => id === current.selectedCategoryId)
  }

  function orderedIds(): string[] {
    return [...(currentCategory()?.channels ?? [])].sort((a, b) => a.position - b.position || a.id.localeCompare(b.id)).map(({ id }) => id)
  }

  function sync(): void {
    const current = snapshot()
    if (current.revision !== lastRevision || current.selectedCategoryId !== lastCategoryId) {
      conflict.value = false
      needsRefresh.value = false
    }
    lastRevision = current.revision
    lastCategoryId = current.selectedCategoryId
  }

  function canMove(direction: -1 | 1): boolean {
    const current = snapshot()
    const ids = orderedIds()
    const index = ids.indexOf(current.selectedChannelId)
    return !pending.value && !needsRefresh.value && current.revision > 0 && index >= 0
      && index + direction >= 0 && index + direction < ids.length
  }

  async function move(direction: -1 | 1): Promise<boolean> {
    if (!canMove(direction)) return false
    const current = snapshot()
    const ids = orderedIds()
    const index = ids.indexOf(current.selectedChannelId)
    const neighbor = ids[index + direction]
    ids[index + direction] = ids[index]
    ids[index] = neighbor
    error.value = null
    status.value = null
    pending.value = true
    try {
      await reorderChannels(current.selectedCategoryId, ids, current.revision, request)
      needsRefresh.value = true
      status.value = 'Порядок каналов сохранён. Обновляем список.'
      changed()
      return true
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось изменить порядок каналов.'
      if (cause instanceof ChannelOrderError && cause.status === 409) {
        conflict.value = true
        needsRefresh.value = true
        changed()
      }
      return false
    } finally { pending.value = false }
  }

  return { canMove, conflict, error, move, needsRefresh, pending, status, sync }
}
