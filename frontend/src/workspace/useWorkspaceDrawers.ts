import { onBeforeUnmount, onMounted, ref } from 'vue'

export function useWorkspaceDrawers() {
  const navOpen = ref(false)
  const membersOpen = ref(false)
  function closeDrawers(): void { navOpen.value = false; membersOpen.value = false }
  function toggleNavigation(): void { membersOpen.value = false; navOpen.value = !navOpen.value }
  function toggleMembers(): void { navOpen.value = false; membersOpen.value = !membersOpen.value }
  function onKeydown(event: KeyboardEvent): void { if (event.key === 'Escape') closeDrawers() }
  onMounted(() => window.addEventListener('keydown', onKeydown))
  onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown))
  return { navOpen, membersOpen, closeDrawers, toggleNavigation, toggleMembers }
}
