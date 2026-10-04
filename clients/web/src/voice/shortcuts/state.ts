import { ref, type Ref } from 'vue'
import { isVoiceShortcutValid, shortcutConflict, type VoiceShortcutAction, type VoiceShortcutBinding } from './model'
import { loadVoiceShortcutPreferences, saveVoiceShortcutPreferences } from './preferences'
export function createShortcutSettings(error: Ref<string | null>, ptt: Ref<string | null>) {
 const microphoneShortcut = ref<VoiceShortcutBinding | null>(null), deafenShortcut = ref<VoiceShortcutBinding | null>(null), shortcutStatus = ref('')
 let account: string | null = null
 function unbindAccount(): void { account = null; microphoneShortcut.value = deafenShortcut.value = null; shortcutStatus.value = ''; error.value = null }
 function bindAccount(id: string): void {
  if (account === id) return
  unbindAccount(); account = id
  const saved = loadVoiceShortcutPreferences(id)
  if (saved.microphone && !shortcutConflict(saved.microphone, null, ptt.value)) microphoneShortcut.value = saved.microphone
  if (saved.deafen && !shortcutConflict(saved.deafen, microphoneShortcut.value, ptt.value)) deafenShortcut.value = saved.deafen
 }
 function setShortcut(action: VoiceShortcutAction, binding: VoiceShortcutBinding | null): boolean {
  if (binding && !isVoiceShortcutValid(binding)) { error.value = 'Назначьте допустимую основную клавишу с Ctrl, Alt, Shift или Meta.'; return false }
  const other = action === 'microphone' ? deafenShortcut.value : microphoneShortcut.value
  const conflict = binding && shortcutConflict(binding, other, ptt.value)
  if (conflict) { error.value = conflict === 'duplicate' ? 'Это сочетание уже назначено.' : conflict === 'ptt' ? 'Сочетание конфликтует с push-to-talk.' : conflict === 'search' ? 'Ctrl/Meta+K зарезервировано для поиска.' : 'Сочетание зарезервировано браузером или системой.'; return false }
  const next = { microphone: action === 'microphone' ? binding : microphoneShortcut.value, deafen: action === 'deafen' ? binding : deafenShortcut.value }
  if (account && !saveVoiceShortcutPreferences(account, next)) { error.value = 'Не удалось сохранить сочетание.'; return false }
  microphoneShortcut.value = next.microphone; deafenShortcut.value = next.deafen; error.value = null; return true
 }
 function resetShortcuts(): void {
  if (account && !saveVoiceShortcutPreferences(account, { microphone: null, deafen: null })) { error.value = 'Не удалось сбросить сочетания.'; return }
  microphoneShortcut.value = deafenShortcut.value = null; shortcutStatus.value = ''; error.value = null
 }
 return { bindAccount, unbindAccount, microphoneShortcut, deafenShortcut, shortcutStatus, setShortcut, resetShortcuts }
}
