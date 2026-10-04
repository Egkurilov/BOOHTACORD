import { describe, expect, it, vi } from 'vitest'
import { focusMemberPopover } from './member_popover_focus'

function panelFixture(hasAction = true) {
  const action = { focus: vi.fn() }
  const close = { focus: vi.fn() }
  const panel = { focus: vi.fn(), querySelector: vi.fn((selector: string) => selector.includes(',') ? close : selector === '.member-popover-actions button' && hasAction ? action : selector === 'header button' ? close : null) }
  return { panel: panel as unknown as HTMLElement, action, close }
}

describe('member profile opening focus', () => {
  it('starts on the primary action rather than the earlier close button', () => {
    const { panel, action, close } = panelFixture()
    focusMemberPopover(panel, false)
    expect(action.focus).toHaveBeenCalledOnce()
    expect(close.focus).not.toHaveBeenCalled()
  })

  it('keeps modal sheet focus on the dialog', () => {
    const { panel, action, close } = panelFixture()
    focusMemberPopover(panel, true)
    expect(panel.focus).toHaveBeenCalledOnce()
    expect(action.focus).not.toHaveBeenCalled()
    expect(close.focus).not.toHaveBeenCalled()
  })

  it('offers close when the own profile has no primary action', () => {
    const { panel, close } = panelFixture(false)
    focusMemberPopover(panel, false)
    expect(close.focus).toHaveBeenCalledOnce()
    expect(() => focusMemberPopover(null, false)).not.toThrow()
  })
})
