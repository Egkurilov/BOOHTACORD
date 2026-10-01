import { ref, type Ref } from 'vue'
import { useWorkspaceDrawerFocus } from './workspace_drawer_focus'

export function useWorkspaceDrawers(activePanel: Ref<string>) {
  const navOpen = ref(false)
  const membersOpen = ref(false)
  function closeDrawers(): void { navOpen.value = false; membersOpen.value = false }
  function toggleNavigation(): void { membersOpen.value = false; navOpen.value = !navOpen.value }
  function toggleMembers(): void { navOpen.value = false; membersOpen.value = !membersOpen.value }
  const { modalDrawer } = useWorkspaceDrawerFocus(navOpen, membersOpen, activePanel, closeDrawers)
  return { navOpen, membersOpen, modalDrawer, closeDrawers, toggleNavigation, toggleMembers }
}
