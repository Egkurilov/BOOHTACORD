import { reservedShortcut } from './reserved'
export type VoiceShortcutAction = 'microphone' | 'deafen'

export interface VoiceShortcutBinding {
  code: string
  ctrlKey: boolean
  altKey: boolean
  shiftKey: boolean
  metaKey: boolean
}
export type VoiceShortcutKeyEvent = Pick<KeyboardEvent, 'key' | 'code' | 'ctrlKey' | 'altKey' | 'shiftKey' | 'metaKey' | 'repeat' | 'isComposing' | 'target' | 'preventDefault' | 'stopPropagation'>

export const modifierCodes = new Set(['ControlLeft', 'ControlRight', 'AltLeft', 'AltRight', 'ShiftLeft', 'ShiftRight', 'MetaLeft', 'MetaRight'])

export function bindingMatchesKeyboardEvent(binding: VoiceShortcutBinding | null, event: Pick<KeyboardEvent, 'code' | 'ctrlKey' | 'altKey' | 'shiftKey' | 'metaKey'>): boolean {
  return Boolean(binding && binding.code === event.code && binding.ctrlKey === event.ctrlKey && binding.altKey === event.altKey && binding.shiftKey === event.shiftKey && binding.metaKey === event.metaKey)
}

export function formatVoiceShortcut(binding: VoiceShortcutBinding | null): string {
  if (!binding) return 'Не назначено'
  const modifiers = [binding.ctrlKey && 'Ctrl', binding.altKey && 'Alt', binding.shiftKey && 'Shift', binding.metaKey && 'Meta'].filter(Boolean)
  const primary = binding.code.replace(/^Key/, '').replace(/^Digit/, '').replace(/^Numpad/, 'Num ')
  return [...modifiers, primary || binding.code].join('+')
}

export function isVoiceShortcutValid(binding: VoiceShortcutBinding | null): boolean {
  if (!binding || !/^(Key[A-Z]|Digit[0-9]|Numpad([0-9]|Add|Subtract|Multiply|Divide|Decimal|Equal|Comma)|F([1-9]|1[0-9]|2[0-4])|Arrow(Up|Down|Left|Right)|Home|End|PageUp|PageDown|Insert|Space|Minus|Equal|BracketLeft|BracketRight|Backslash|Semicolon|Quote|Comma|Period|Slash|Backquote)$/.test(binding.code) || modifierCodes.has(binding.code) || ['Space', 'F5', 'F11', 'F12'].includes(binding.code)) return false
  if (!(binding.ctrlKey || binding.altKey || binding.shiftKey || binding.metaKey)) return !/^Key[A-Z]|^Digit\d|^Numpad\d/i.test(binding.code)
  return true
}

export function shortcutConflict(binding: VoiceShortcutBinding, other: VoiceShortcutBinding | null, pttCode: string | null): 'duplicate' | 'ptt' | 'search' | 'reserved' | null {
  if (other && bindingMatchesKeyboardEvent(binding, other)) return 'duplicate'
  if (pttCode && binding.code === pttCode) return 'ptt'
  if ((binding.ctrlKey || binding.metaKey) && binding.code === 'KeyK') return 'search'
  if (reservedShortcut(binding)) return 'reserved'
  return null
}

export function isVoiceShortcutTargetBlocked(target: EventTarget | null): boolean {
  const element = target as HTMLElement | null
  return Boolean(element?.closest?.('input, textarea, select, button, [role="button"], dialog, [contenteditable]:not([contenteditable="false"]), [role="textbox"], [role="searchbox"], [role="dialog"]'))
}

