export type VoiceShortcutAction = 'microphone' | 'deafen'

export interface VoiceShortcutBinding {
  code: string
  ctrlKey: boolean
  altKey: boolean
  shiftKey: boolean
  metaKey: boolean
}
export type VoiceShortcutKeyEvent = Pick<KeyboardEvent, 'key' | 'code' | 'ctrlKey' | 'altKey' | 'shiftKey' | 'metaKey' | 'repeat' | 'isComposing' | 'target' | 'preventDefault' | 'stopPropagation'>

const modifierCodes = new Set(['ControlLeft', 'ControlRight', 'AltLeft', 'AltRight', 'ShiftLeft', 'ShiftRight', 'MetaLeft', 'MetaRight'])

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
  if (!binding || !binding.code || modifierCodes.has(binding.code)) return false
  if (!(binding.ctrlKey || binding.altKey || binding.shiftKey || binding.metaKey)) return !/^Key[A-Z]|^Digit\d|^Numpad\d/i.test(binding.code)
  return true
}

export function shortcutConflict(binding: VoiceShortcutBinding, other: VoiceShortcutBinding | null, pttCode: string | null): 'duplicate' | 'ptt' | 'search' | null {
  if (other && bindingMatchesKeyboardEvent(binding, other)) return 'duplicate'
  if (pttCode && binding.code === pttCode) return 'ptt'
  if ((binding.ctrlKey || binding.metaKey) && !binding.altKey && !binding.shiftKey && binding.code === 'KeyK') return 'search'
  return null
}

export function isVoiceShortcutTargetBlocked(target: EventTarget | null): boolean {
  const element = target as HTMLElement | null
  return Boolean(element?.closest?.('input, textarea, select, [contenteditable]:not([contenteditable="false"]), [role="textbox"], [role="searchbox"], [role="dialog"]'))
}

export function captureVoiceShortcutAssignment(event: VoiceShortcutKeyEvent, stop: () => void, assign: (binding: VoiceShortcutBinding) => void, clear: () => void): void {
  if (event.key === 'Tab') { stop(); return }
  event.preventDefault()
  if (event.key === 'Escape') { event.stopPropagation(); stop(); return }
  if (event.repeat || event.isComposing) return
  if (event.key === 'Backspace' || event.key === 'Delete') { stop(); clear(); return }
  if (modifierCodes.has(event.code)) return
  assign({ code: event.code, ctrlKey: event.ctrlKey, altKey: event.altKey, shiftKey: event.shiftKey, metaKey: event.metaKey })
  stop()
}

