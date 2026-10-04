import { modifierCodes, type VoiceShortcutKeyEvent, type VoiceShortcutBinding } from './model'
export function captureVoiceShortcutAssignment(event: VoiceShortcutKeyEvent, stop: () => void, assign: (binding: VoiceShortcutBinding) => void, clear: () => void): void {
  if (event.repeat || event.isComposing) return
  if (event.key === 'Tab') { stop(); return }
  event.preventDefault()
  event.stopPropagation()
  if (event.key === 'Escape') { stop(); return }
  if (event.key === 'Backspace' || event.key === 'Delete') { stop(); clear(); return }
  if (modifierCodes.has(event.code)) return
  assign({ code: event.code, ctrlKey: event.ctrlKey, altKey: event.altKey, shiftKey: event.shiftKey, metaKey: event.metaKey })
  stop()
}

