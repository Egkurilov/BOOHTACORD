import { ref } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'

import type { AdminTopologyRequest } from './admin_topology_client'
import { CategoryMutationError, renameCategory, reorderCategories } from './category_mutation_client'
import type { TopologyCategory } from './topology_client'

export interface CategoryEditorSnapshot { categories: TopologyCategory[]; revision: number; selectedCategoryId: string }

export function createCategoryEditor(snapshot: () => CategoryEditorSnapshot, changed: () => void, request?: AdminTopologyRequest) {
  const renameDraft = ref('')
  const pending = ref(false)
  const conflict = ref(false)
  const needsRefresh = ref(false)
  const error = ref<string | null>(null)
  const status = ref<string | null>(null)
  let lastSelected = ''
  let lastRevision = -1
  let dirty = false

  function ordered(): TopologyCategory[] {
    return [...snapshot().categories].sort((a, b) => a.position - b.position || a.id.localeCompare(b.id))
  }

  function sync(): void {
    const current = snapshot()
    const selected = current.categories.find((item) => item.id === current.selectedCategoryId)
    if (current.selectedCategoryId !== lastSelected) {
      renameDraft.value = selected?.name ?? ''
      dirty = false
      conflict.value = false
      needsRefresh.value = false
    } else if (current.revision !== lastRevision) {
      conflict.value = false
      needsRefresh.value = false
      if (!dirty) renameDraft.value = selected?.name ?? ''
    }
    lastSelected = current.selectedCategoryId
    lastRevision = current.revision
  }

  function setRenameDraft(value: string): void { renameDraft.value = value; dirty = true }

  function canMove(direction: -1 | 1): boolean {
    const current = snapshot()
    const index = ordered().findIndex(({ id }) => id === current.selectedCategoryId)
    return !pending.value && !needsRefresh.value && current.revision > 0 && index >= 0 && index + direction >= 0 && index + direction < current.categories.length
  }

  function failed(cause: unknown): void {
    error.value = cause instanceof Error ? cause.message : 'Не удалось изменить разделы.'
    if (cause instanceof CategoryMutationError && cause.status === 409) {
      conflict.value = true
      needsRefresh.value = true
      changed()
    }
  }

  async function rename(): Promise<boolean> {
    const current = snapshot()
    if (pending.value || needsRefresh.value || !current.selectedCategoryId) return false
    error.value = null
    status.value = null
    if (!renameDraft.value.trim() || !validCodePointLength(renameDraft.value, 1, 80)) {
      error.value = 'Введите название раздела до 80 символов.'
      return false
    }
    pending.value = true
    try {
      const renamed = await renameCategory(current.selectedCategoryId, renameDraft.value, current.revision, request)
      renameDraft.value = renamed.name
      dirty = false
      needsRefresh.value = true
      status.value = 'Раздел переименован. Обновляем список.'
      changed()
      return true
    } catch (cause) { failed(cause); return false }
    finally { pending.value = false }
  }

  async function move(direction: -1 | 1): Promise<boolean> {
    if (!canMove(direction)) return false
    const current = snapshot()
    const ids = ordered().map(({ id }) => id)
    const index = ids.indexOf(current.selectedCategoryId)
    const neighbor = ids[index + direction]
    ids[index + direction] = ids[index]
    ids[index] = neighbor
    error.value = null
    status.value = null
    pending.value = true
    try {
      await reorderCategories(ids, current.revision, request)
      needsRefresh.value = true
      status.value = 'Порядок разделов сохранён. Обновляем список.'
      changed()
      return true
    } catch (cause) { failed(cause); return false }
    finally { pending.value = false }
  }

  return { canMove, conflict, error, move, needsRefresh, pending, rename, renameDraft, setRenameDraft, status, sync }
}
