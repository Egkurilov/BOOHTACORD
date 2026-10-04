import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

export function useCompactComposerActions() {
  const compact = ref(false)
  const menuOpen = ref(false)
  const trigger = ref<HTMLButtonElement | null>(null)
  const firstAction = ref<HTMLButtonElement | null>(null)
  let media: MediaQueryList | null = null

  function sync(): void {
    compact.value = media?.matches ?? false
    if (!compact.value) menuOpen.value = false
  }
  onMounted(() => {
    media = window.matchMedia('(max-width: 720px)')
    sync()
    media.addEventListener('change', sync)
  })
  onBeforeUnmount(() => media?.removeEventListener('change', sync))

  function toggle(): void {
    menuOpen.value = !menuOpen.value
    if (menuOpen.value) void nextTick(() => firstAction.value?.focus())
  }
  function close(restoreFocus = false): void {
    menuOpen.value = false
    if (restoreFocus) void nextTick(() => trigger.value?.focus())
  }
  function onFocusOut(event: FocusEvent): void {
    if (!(event.relatedTarget instanceof Node) || !(event.currentTarget as HTMLElement).contains(event.relatedTarget)) close()
  }
  return { compact, menuOpen, trigger, firstAction, toggle, close, onFocusOut }
}
