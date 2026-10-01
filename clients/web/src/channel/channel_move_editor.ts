import { ref } from 'vue'

import type { AdminTopologyRequest } from './admin_topology_client'
import { ChannelMoveError, moveChannel } from './channel_move_client'
import type { TopologyCategory } from './topology_client'

export interface ChannelMoveSnapshot { categories: TopologyCategory[]; revision: number; selectedChannelId: string }

export function createChannelMoveEditor(snapshot: () => ChannelMoveSnapshot, changed: () => void, request?: AdminTopologyRequest) {
  const targetCategoryId = ref('')
  const pending = ref(false)
  const conflict = ref(false)
  const needsRefresh = ref(false)
  const error = ref<string | null>(null)
  const status = ref<string | null>(null)
  let selectedId = ''
  let revision = -1

  function sourceCategoryId(): string | undefined {
    return snapshot().categories.find(({ channels }) => channels.some(({ id }) => id === snapshot().selectedChannelId))?.id
  }

  function sync(): void {
    const current = snapshot()
    if (current.selectedChannelId !== selectedId) {
      targetCategoryId.value = sourceCategoryId() ?? ''
      conflict.value = false
      needsRefresh.value = false
    } else if (current.revision !== revision) {
      conflict.value = false
      needsRefresh.value = false
      if (!current.categories.some(({ id }) => id === targetCategoryId.value)) targetCategoryId.value = sourceCategoryId() ?? ''
    }
    selectedId = current.selectedChannelId
    revision = current.revision
  }

  function setTargetCategoryId(id: string): void { targetCategoryId.value = id }

  function canMove(): boolean {
    const current = snapshot()
    return !pending.value && !needsRefresh.value && current.revision > 0 && Boolean(sourceCategoryId())
      && targetCategoryId.value !== sourceCategoryId() && current.categories.some(({ id }) => id === targetCategoryId.value)
  }

  async function move(): Promise<boolean> {
    if (!canMove()) return false
    const current = snapshot()
    const target = targetCategoryId.value
    error.value = null
    status.value = null
    pending.value = true
    try {
      await moveChannel(current.selectedChannelId, target, current.revision, request)
      needsRefresh.value = true
      status.value = 'Канал перенесён. Обновляем список.'
      changed()
      return true
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось перенести канал.'
      if (cause instanceof ChannelMoveError && cause.status === 409) {
        conflict.value = true
        needsRefresh.value = true
        changed()
      }
      return false
    } finally { pending.value = false }
  }

  return { canMove, conflict, error, move, needsRefresh, pending, setTargetCategoryId, sourceCategoryId, status, sync, targetCategoryId }
}
