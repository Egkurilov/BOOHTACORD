export type WorkspaceHistoryView = 'nav' | 'members' | 'search' | 'admin' | 'audio' | 'profile'

const historyStateKey = '__boohtacordWorkspaceView'
const workspacePanels = ['admin', 'audio', 'profile'] as const

export interface WorkspaceDrawerHistoryPort {
  readonly state: unknown
  pushState(data: unknown, title?: string, url?: string | URL | null): void
  replaceState(data: unknown, title?: string, url?: string | URL | null): void
}

export interface WorkspaceDrawerStateTarget {
  navOpen: { value: boolean }
  membersOpen: { value: boolean }
  activePanel: { value: string }
}

function stateRecord(state: unknown): Record<string, unknown> {
  return state !== null && typeof state === 'object' && !Array.isArray(state)
    ? { ...(state as Record<string, unknown>) }
    : {}
}

export function workspaceHistoryViewFromState(state: unknown): WorkspaceHistoryView | null {
  if (state === null || typeof state !== 'object' || Array.isArray(state)) return null
  const drawer = (state as Record<string, unknown>)[historyStateKey]
  return drawer === 'nav' || drawer === 'members' || drawer === 'search' || drawer === 'admin' || drawer === 'audio' || drawer === 'profile' ? drawer : null
}

export function restoreWorkspaceDrawerState(target: WorkspaceDrawerStateTarget, historyState: unknown): void {
  const view = workspaceHistoryViewFromState(historyState)
  target.navOpen.value = view === 'nav'
  target.membersOpen.value = view === 'members'
  if (view === 'search' || view === 'admin' || view === 'audio' || view === 'profile') target.activePanel.value = view
  else if (view === null && (target.activePanel.value === 'search' || workspacePanels.includes(target.activePanel.value as typeof workspacePanels[number]))) target.activePanel.value = 'none'
}

export function syncWorkspaceDrawerHistory(history: WorkspaceDrawerHistoryPort, view: WorkspaceHistoryView | null): void {
  const current = workspaceHistoryViewFromState(history.state)
  if (current === view) return
  if (view) {
    const next = { ...stateRecord(history.state), [historyStateKey]: view }
    if (current) history.replaceState(next, '')
    else history.pushState(next, '')
    return
  }
  if (current) clearWorkspaceDrawerHistory(history)
}

/** Remove an overlay entry when a drawer selection itself navigates to another workspace context. */
export function clearWorkspaceDrawerHistory(history: WorkspaceDrawerHistoryPort): void {
  if (!workspaceHistoryViewFromState(history.state)) return
  const next = stateRecord(history.state)
  delete next[historyStateKey]
  history.replaceState(next, '')
}
