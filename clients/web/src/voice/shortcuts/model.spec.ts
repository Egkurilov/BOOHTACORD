import { describe, expect, it, vi } from 'vitest'
import { isVoiceShortcutValid, shortcutConflict, captureVoiceShortcutAssignment, isVoiceShortcutTargetBlocked } from '../voice_shortcut'
const binding = { code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false }
describe('shortcut completion', () => {
 it('rejects browser/OS/control keys and modified search variants', () => {
  for (const code of ['Tab', 'Escape', 'Unidentified', 'F5']) expect(isVoiceShortcutValid({ ...binding, code })).toBe(false)
  expect(shortcutConflict({ ...binding, code: 'KeyW' }, null, null)).toBe('reserved')
  expect(shortcutConflict({ ...binding, ctrlKey:false,metaKey:true }, null, null)).toBe('reserved')
  expect(shortcutConflict({ ...binding, code: 'KeyK', shiftKey: true }, null, null)).toBe('search')
 })
 it('ignores composing clear and repeat; keeps Tab navigation', () => {
  const stop = vi.fn(), assign = vi.fn(), clear = vi.fn(), preventDefault = vi.fn()
  const event = { ...binding, key: 'Backspace', repeat: false, isComposing: true, target: null, preventDefault, stopPropagation: vi.fn() }
  captureVoiceShortcutAssignment(event, stop, assign, clear); expect(clear).not.toHaveBeenCalled(); expect(preventDefault).not.toHaveBeenCalled()
  captureVoiceShortcutAssignment({ ...event, isComposing: false, key: 'Tab' }, stop, assign, clear); expect(stop).toHaveBeenCalledOnce(); expect(preventDefault).not.toHaveBeenCalled()
 })
 it('blocks native dialog and button focus targets', () => {
  expect(isVoiceShortcutTargetBlocked({ closest: (s: string) => s.includes('dialog') && s.includes('button') ? {} : null } as unknown as EventTarget)).toBe(true)
 })
})
