import { nextTick, onBeforeUnmount, ref, watch, type Ref } from 'vue'
import { draftKey, draftMemoryEpoch } from '../draft_memory'
import { capture, restore, type Position } from './dom'
import { loadPosition, savePosition } from './memory'

export function useContextPosition(accountId: string, kind: 'CHANNEL' | 'DIRECT_MESSAGE', scope: () => string,
  root: Ref<HTMLElement | null>, contextOpen: () => boolean, loaded: () => boolean, restored = ref<Position | null>(null)) {
  const epoch = draftMemoryEpoch()
  let key = draftKey(accountId, kind, scope()), previous: Position | null = null, focus: HTMLElement | null = null
  const main = () => root.value?.querySelector<HTMLElement>('.message-history-wrap .message-list') ?? null
  function save(): void {
    if (epoch !== draftMemoryEpoch()) return
    const context = root.value?.querySelector<HTMLElement>('.search-context-list')
    const viewport = context?.clientHeight ? context : main()
    const position = capture(viewport)
    if (position) savePosition(key, position)
  }
  watch(contextOpen, async (open, wasOpen) => {
    if (open && !wasOpen) { previous = capture(main()); focus = document.activeElement instanceof HTMLElement ? document.activeElement : null }
    if (!open && wasOpen) {
      await nextTick()
      if (previous && !restore(main(), previous)) restored.value = previous
      if (focus?.isConnected) focus.focus({ preventScroll: true })
      else root.value?.querySelector<HTMLElement>('textarea')?.focus({ preventScroll: true })
    }
  }, { flush: 'pre' })
  watch(scope, () => { save(); key = draftKey(accountId, kind, scope()); previous = null; restored.value = null }, { flush: 'pre' })
  watch(loaded, async ready => {
    if (!ready) return
    const target = loadPosition(key)
    const requestKey = key
    if (!target) return
    await nextTick()
    if (requestKey !== key || epoch !== draftMemoryEpoch()) return
    if (contextOpen()) { previous = target; return }
    if (!restore(main(), target)) restored.value = target
  }, { immediate: true, flush: 'post' })
  onBeforeUnmount(save)
  async function showLatest(): Promise<void> {
    previous = null; restored.value = null
    await nextTick()
    const viewport = main()
    if (viewport) viewport.scrollTop = viewport.scrollHeight
  }
  return { restored, save, showLatest }
}
