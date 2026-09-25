import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { focusBoundaryTarget } from './workspace_drawer_focus'

const element = () => ({} as HTMLElement)
const source = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8')

describe('workspace drawer keyboard focus', () => {
  it('wraps Tab at both ends and recovers focus that escaped the modal drawer', () => {
    const first = element(); const middle = element(); const last = element()
    const items = [first, middle, last]
    expect(focusBoundaryTarget(items, last, false)).toBe(first)
    expect(focusBoundaryTarget(items, first, true)).toBe(last)
    expect(focusBoundaryTarget(items, middle, false)).toBeNull()
    expect(focusBoundaryTarget(items, element(), false)).toBe(first)
    expect(focusBoundaryTarget(items, element(), true)).toBe(last)
    expect(focusBoundaryTarget([], element(), false)).toBeNull()
  })

  it('connects modal semantics to visible drawers while leaving the member popover non-modal', () => {
    const app = source('./WorkspaceApp.vue')
    const drawers = source('./useWorkspaceDrawers.ts')
    const popover = source('./MemberPopover.vue')
    expect(app).toContain('modalDrawer')
    expect(app).toContain('aria-modal')
    expect(drawers).toContain('useWorkspaceDrawerFocus')
    expect(popover).toContain('aria-modal="false"')
    expect(popover).toContain('event.stopPropagation()')
  })
})
