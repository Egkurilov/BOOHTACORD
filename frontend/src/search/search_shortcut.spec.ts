import { describe, expect, it, vi } from 'vitest'

import { shouldOpenSearchShortcut, type SearchShortcutEvent } from './search_shortcut'

function shortcut(overrides: Partial<SearchShortcutEvent> = {}): SearchShortcutEvent {
  return { key: 'k', ctrlKey: true, metaKey: false, altKey: false, shiftKey: false, repeat: false, isComposing: false, target: null, ...overrides }
}

describe('search shortcut focus guard', () => {
  it('accepts Ctrl+K and Meta+K when focus is outside editable controls', () => {
    expect(shouldOpenSearchShortcut(shortcut())).toBe(true)
    expect(shouldOpenSearchShortcut(shortcut({ ctrlKey: false, metaKey: true, key: 'K' }))).toBe(true)
  })

  it('does not steal the shortcut from inputs, editors, or text widgets', () => {
    const editable = { closest: vi.fn(() => ({})) }
    expect(shouldOpenSearchShortcut(shortcut({ target: editable }))).toBe(false)
    expect(editable.closest).toHaveBeenCalledWith(expect.stringContaining('[contenteditable]'))
  })

  it('rejects other keys, alt-modified keys, repeats, and IME composition', () => {
    expect(shouldOpenSearchShortcut(shortcut({ key: 'f' }))).toBe(false)
    expect(shouldOpenSearchShortcut(shortcut({ altKey: true }))).toBe(false)
    expect(shouldOpenSearchShortcut(shortcut({ shiftKey: true }))).toBe(false)
    expect(shouldOpenSearchShortcut(shortcut({ repeat: true }))).toBe(false)
    expect(shouldOpenSearchShortcut(shortcut({ isComposing: true }))).toBe(false)
  })
})
