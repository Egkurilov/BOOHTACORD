import { computed, onBeforeUnmount, onMounted, ref, type Ref } from 'vue'

export function memberHeaderExpanded(desktop: boolean, voiceStageWide: boolean, membersOpen: boolean): boolean {
  return desktop && !voiceStageWide ? !membersOpen : membersOpen
}

export function useMemberHeaderExpanded(voiceStageWide: Readonly<Ref<boolean>>, membersOpen: Readonly<Ref<boolean>>, closeDrawers: () => void) {
  const desktop = ref(typeof window !== 'undefined' && window.innerWidth >= 1280)
  function syncBreakpoint(): void {
    const next = window.innerWidth >= 1280
    if (next !== desktop.value) { closeDrawers(); desktop.value = next }
  }
  onMounted(() => { window.addEventListener('resize', syncBreakpoint); syncBreakpoint() })
  onBeforeUnmount(() => window.removeEventListener('resize', syncBreakpoint))
  return computed(() => memberHeaderExpanded(desktop.value, voiceStageWide.value, membersOpen.value))
}
