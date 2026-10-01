import { getActivePinia, type Pinia } from 'pinia'
import { clearDraftMemory } from '../conversation/draft_memory'

/** Pinia survives the guest screen; discard every authenticated store before another login. */
export function clearAuthenticatedState(pinia: Pinia | undefined = getActivePinia()): void {
  clearDraftMemory()
  if (!pinia) return
  for (const store of [...pinia._s.values()]) store.$dispose()
  pinia.state.value = {}
}
