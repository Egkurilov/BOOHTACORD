import { describe, expect, it, vi } from 'vitest'

import { captureVoiceShortcutAssignment, formatVoiceShortcut, isVoiceShortcutTargetBlocked, isVoiceShortcutValid, shortcutConflict } from './voice_shortcut'
import { loadVoiceShortcutPreferences, saveVoiceShortcutPreferences } from './voice_shortcut_preferences'

function event(overrides: Partial<KeyboardEvent> = {}) {
  return { key: 'm', code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false, repeat: false, isComposing: false, target: null, preventDefault: vi.fn(), stopPropagation: vi.fn(), ...overrides } as KeyboardEvent
}

describe('voice shortcut contract', () => {
  it('captures a modifier combo and supports clear/cancel keys', () => {
    const stop = vi.fn(); const assign = vi.fn(); const clear = vi.fn()
    captureVoiceShortcutAssignment(event(), stop, assign, clear)
    expect(assign).toHaveBeenCalledWith({ code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false })
    const backspace = event({ key: 'Backspace', code: 'Backspace' }); captureVoiceShortcutAssignment(backspace, stop, assign, clear)
    expect(clear).toHaveBeenCalledOnce()
    const escape = event({ key: 'Escape', code: 'Escape' }); captureVoiceShortcutAssignment(escape, stop, assign, clear)
    expect(escape.stopPropagation).toHaveBeenCalledOnce()
  })

  it('keeps Tab available for focus navigation and rejects bare alphanumeric keys', () => {
    const tab = event({ key: 'Tab', code: 'Tab' }); const assign = vi.fn(); const stop = vi.fn()
    captureVoiceShortcutAssignment(tab, stop, assign, vi.fn())
    expect(tab.preventDefault).not.toHaveBeenCalled(); expect(assign).not.toHaveBeenCalled()
    expect(isVoiceShortcutValid({ code: 'KeyM', ctrlKey: false, altKey: false, shiftKey: false, metaKey: false })).toBe(false)
    expect(isVoiceShortcutValid({ code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false })).toBe(true)
  })

  it('detects assignment conflicts and blocked targets', () => {
    const combo = { code: 'KeyK', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false }
    expect(shortcutConflict(combo, combo, null)).toBe('duplicate')
    expect(shortcutConflict({ ...combo, code: 'KeyP' }, null, 'KeyP')).toBe('ptt')
    expect(shortcutConflict(combo, null, null)).toBe('search')
    const input = { closest: (selector: string) => selector.includes('input') ? {} : null }
    expect(isVoiceShortcutTargetBlocked(input as unknown as EventTarget)).toBe(true)
  })

  it('formats and persists shortcuts per account', () => {
    const storage = new Map<string, string>(); vi.stubGlobal('localStorage', { getItem: (k: string) => storage.get(k) ?? null, setItem: (k: string, v: string) => storage.set(k, v) })
    const shortcuts = { microphone: { code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false }, deafen: null }
    saveVoiceShortcutPreferences('a', shortcuts)
    expect(loadVoiceShortcutPreferences('a')).toEqual(shortcuts)
    expect(loadVoiceShortcutPreferences('b')).toEqual({ microphone: null, deafen: null })
    expect(formatVoiceShortcut(shortcuts.microphone)).toBe('Ctrl+M')
  })
})
