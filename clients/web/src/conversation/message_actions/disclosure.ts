import { ref } from 'vue'

export function useMessageActionDisclosure() {
  const actionsOpen = ref(false)
  const actionsToggle = ref<HTMLButtonElement | null>(null)
  const row = ref<HTMLElement | null>(null)

  function closeActions(event: KeyboardEvent): void {
    if (!actionsOpen.value) return
    event.stopPropagation()
    actionsOpen.value = false
    actionsToggle.value?.focus()
  }

  function onRowPointerDown(event: PointerEvent): void {
    if (event.pointerType !== 'touch' && event.pointerType !== 'pen') return
    if (!(event.target instanceof Element) || event.target.closest('button, a, input, textarea, select, [role="button"]')) return
    actionsOpen.value = true
    row.value?.focus()
  }

  function onRowFocusOut(event: FocusEvent): void {
    if (event.relatedTarget instanceof Node && row.value?.contains(event.relatedTarget)) return
    actionsOpen.value = false
  }

  return {
    actionsOpen,
    actionsToggle,
    row,
    closeActions,
    onRowPointerDown,
    onRowFocusOut,
  }
}
