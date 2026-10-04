import type { VoiceShortcutBinding } from './model'
const primary = new Set(['KeyR', 'KeyW', 'KeyT', 'KeyN', 'KeyL', 'KeyP', 'KeyF', 'KeyO', 'KeyS', 'KeyD', 'KeyQ', 'KeyH', 'KeyJ', 'KeyU', 'KeyB', 'KeyA', 'KeyC', 'KeyX', 'KeyV', 'KeyZ', 'KeyE', 'KeyI', 'Tab'])
export function reservedShortcut(binding: VoiceShortcutBinding): boolean {
 const { code, ctrlKey, altKey, shiftKey, metaKey } = binding
 if ((ctrlKey || metaKey) && !altKey && (primary.has(code) || (shiftKey && code === 'KeyM'))) return true
 if (metaKey && !altKey && /^(Key[A-Z]|Digit[0-9]|Arrow(Up|Down|Left|Right))$/.test(code)) return true
 return (altKey && ['F4', 'Tab', 'Space'].includes(code)) || (ctrlKey && altKey && code === 'Delete')
}
