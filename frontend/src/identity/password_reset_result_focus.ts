import { nextTick, watch, type Ref } from 'vue'

export function usePasswordResetResultFocus(visible: Readonly<Ref<boolean>>, target: Ref<HTMLElement | null>): void {
  watch(visible, async (showResult) => {
    if (!showResult) return
    await nextTick()
    target.value?.focus()
  }, { immediate: true, flush: 'post' })
}
