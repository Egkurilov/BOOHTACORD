import { describe, expect, it } from 'vitest'
import { clearWorkspaceDrawerHistory, restoreWorkspaceDrawerState, syncWorkspaceDrawerHistory, workspaceHistoryViewFromState, type WorkspaceDrawerHistoryPort, type WorkspaceDrawerStateTarget } from './workspace_drawer_history'

function historyPort(initialState: unknown = null): WorkspaceDrawerHistoryPort & { calls: Array<{ kind: string; state?: unknown }> } {
  let state = initialState
  const calls: Array<{ kind: string; state?: unknown }> = []
  return {
    get state() { return state },
    calls,
    pushState(next) { state = next; calls.push({ kind: 'push', state: next }) },
    replaceState(next) { state = next; calls.push({ kind: 'replace', state: next }) },
  }
}

describe('workspace drawer browser history', () => {
  it('adds one history entry when an overlay opens and preserves unrelated state', () => {
    const history = historyPort({ route: '/guild/general', scroll: 42 })

    syncWorkspaceDrawerHistory(history, 'nav')

    expect(history.calls).toHaveLength(1)
    expect(history.calls[0]?.kind).toBe('push')
    expect(history.calls[0]?.state).toMatchObject({ route: '/guild/general', scroll: 42 })
    expect(workspaceHistoryViewFromState(history.state)).toBe('nav')
  })

  it('replaces the overlay marker when switching drawers without adding another Back step', () => {
    const history = historyPort({ __boohtacordWorkspaceView: 'nav', route: '/guild/general' })

    syncWorkspaceDrawerHistory(history, 'members')

    expect(history.calls).toHaveLength(1)
    expect(history.calls[0]?.kind).toBe('replace')
    expect(workspaceHistoryViewFromState(history.state)).toBe('members')
  })

  it('clears a manually closed overlay immediately and ignores a close with no drawer entry', () => {
    const withDrawer = historyPort({ __boohtacordWorkspaceView: 'search' })
    const withoutDrawer = historyPort({ route: '/guild/general' })

    syncWorkspaceDrawerHistory(withDrawer, null)
    syncWorkspaceDrawerHistory(withoutDrawer, null)

    expect(withDrawer.calls).toEqual([{ kind: 'replace', state: {} }])
    expect(withoutDrawer.calls).toEqual([])
  })

  it('removes the drawer marker without leaving a forward-reopen step when selection navigates', () => {
    const history = historyPort({ __boohtacordWorkspaceView: 'nav', route: '/guild/general' })

    clearWorkspaceDrawerHistory(history)

    expect(history.calls[0]?.kind).toBe('replace')
    expect(history.state).toEqual({ route: '/guild/general' })
  })

  it('accepts only known drawer markers', () => {
    expect(workspaceHistoryViewFromState({ __boohtacordWorkspaceView: 'search' })).toBe('search')
    expect(workspaceHistoryViewFromState({ __boohtacordWorkspaceView: 'admin' })).toBe('admin')
    expect(workspaceHistoryViewFromState({ __boohtacordWorkspaceView: 'invalid' })).toBeNull()
    expect(workspaceHistoryViewFromState(null)).toBeNull()
  })

  it('restores the marker drawer on Forward/refresh and clears only the search panel on close', () => {
    const target: WorkspaceDrawerStateTarget = {
      navOpen: { value: false }, membersOpen: { value: false }, activePanel: { value: 'admin' },
    }

    restoreWorkspaceDrawerState(target, { __boohtacordWorkspaceView: 'members' })
    expect(target).toEqual({ navOpen: { value: false }, membersOpen: { value: true }, activePanel: { value: 'admin' } })
    restoreWorkspaceDrawerState(target, { __boohtacordWorkspaceView: 'search' })
    expect(target.activePanel.value).toBe('search')
    restoreWorkspaceDrawerState(target, { route: '/guild/general' })
    expect(target).toEqual({ navOpen: { value: false }, membersOpen: { value: false }, activePanel: { value: 'none' } })
  })

  it('restores a semantic admin view when browser Back returns from an overlay', () => {
    const target: WorkspaceDrawerStateTarget = {
      navOpen: { value: false }, membersOpen: { value: false }, activePanel: { value: 'none' },
    }

    restoreWorkspaceDrawerState(target, { __boohtacordWorkspaceView: 'admin', route: '/guild/general' })
    expect(target.activePanel.value).toBe('admin')
    restoreWorkspaceDrawerState(target, { route: '/guild/general' })
    expect(target.activePanel.value).toBe('none')
  })
})
