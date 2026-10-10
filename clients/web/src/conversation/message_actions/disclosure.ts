import { onBeforeUnmount, ref } from 'vue'

export function useMessageActionDisclosure() {
  const actionsOpen = ref(false)
  const actionsToggle = ref<HTMLButtonElement | null>(null)
  const row = ref<HTMLElement | null>(null)
  let touchPress: { pointerId: number; x: number; y: number } | null = null
  let longPressTimer: number | null = null

  function cancelLongPress(): void {
    if (longPressTimer !== null) window.clearTimeout(longPressTimer)
    longPressTimer = null
    touchPress = null
  }

  function closeActions(event: KeyboardEvent): void {
    if (!actionsOpen.value) return
    event.stopPropagation()
    actionsOpen.value = false
    actionsToggle.value?.focus()
  }

  function onRowPointerDown(event: PointerEvent): void {
    if (event.pointerType !== 'touch' && event.pointerType !== 'pen') return
    if (!(event.target instanceof Element) || event.target.closest('button, a, input, textarea, select, [role="button"]')) return
    cancelLongPress()
    touchPress = { pointerId: event.pointerId, x: event.clientX, y: event.clientY }
    row.value?.focus({ preventScroll: true })
    const pointerId = event.pointerId
    longPressTimer = window.setTimeout(() => {
      if (touchPress?.pointerId !== pointerId) return
      actionsOpen.value = true
      longPressTimer = null
      actionsToggle.value?.focus()
    }, 500)
  }

  function onRowPointerMove(event: PointerEvent): void {
    const press = touchPress
    if (press?.pointerId !== event.pointerId) return
    if (Math.hypot(event.clientX - press.x, event.clientY - press.y) > 10) cancelLongPress()
  }

  function onRowPointerEnd(event: PointerEvent): void {
    if (touchPress?.pointerId === event.pointerId) cancelLongPress()
  }

  function onRowFocusOut(event: FocusEvent): void {
    if (event.relatedTarget instanceof Node && row.value?.contains(event.relatedTarget)) return
    actionsOpen.value = false
  }

  onBeforeUnmount(cancelLongPress)

  return {
    actionsOpen,
    actionsToggle,
    row,
    closeActions,
    onRowPointerDown,
    onRowPointerMove,
    onRowPointerEnd,
    onRowFocusOut,
  }
}
