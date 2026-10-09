import { onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue'
import { useWorkspaceDrawerFocus } from './workspace_drawer_focus'
import { clearWorkspaceDrawerHistory, restoreWorkspaceDrawerState, syncWorkspaceDrawerHistory, type WorkspaceHistoryView } from './workspace_drawer_history'

export function useWorkspaceDrawers(activePanel: Ref<string>) {
  const navOpen = ref(false)
  const membersOpen = ref(false)
  function closeDrawers(): void { navOpen.value = false; membersOpen.value = false }
  function closeDrawersForNavigation(): void {
    if (typeof window !== 'undefined') clearWorkspaceDrawerHistory(window.history)
    closeDrawers()
  }
  function toggleNavigation(): void { membersOpen.value = false; navOpen.value = !navOpen.value }
  function toggleMembers(): void { navOpen.value = false; membersOpen.value = !membersOpen.value }
  function activeDrawer(): WorkspaceHistoryView | null {
    if (navOpen.value) return 'nav'
    if (membersOpen.value) return 'members'
    return activePanel.value === 'search' || activePanel.value === 'admin' || activePanel.value === 'audio' || activePanel.value === 'profile'
      ? activePanel.value
      : null
  }
  function syncHistory(): void {
    if (typeof window !== 'undefined') syncWorkspaceDrawerHistory(window.history, activeDrawer())
  }
  function onPopState(event: PopStateEvent): void {
    restoreWorkspaceDrawerState({ navOpen, membersOpen, activePanel }, event.state)
  }
  watch([navOpen, membersOpen, activePanel], syncHistory, { flush: 'post' })
  onMounted(() => {
    window.addEventListener('popstate', onPopState)
    restoreWorkspaceDrawerState({ navOpen, membersOpen, activePanel }, window.history.state)
  })
  onBeforeUnmount(() => window.removeEventListener('popstate', onPopState))
  const { modalDrawer } = useWorkspaceDrawerFocus(navOpen, membersOpen, activePanel, closeDrawers)
  return { navOpen, membersOpen, modalDrawer, closeDrawers, closeDrawersForNavigation, toggleNavigation, toggleMembers }
}
