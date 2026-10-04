import { isVoiceShortcutValid, type VoiceShortcutAction, type VoiceShortcutBinding } from './voice_shortcut'

type StoredShortcuts = Partial<Record<VoiceShortcutAction, VoiceShortcutBinding | null>>
const key = (accountId: string): string => `voice-shortcuts:v1:${accountId}`

export function loadVoiceShortcutPreferences(accountId: string): Record<VoiceShortcutAction, VoiceShortcutBinding | null> {
  const empty = { microphone: null, deafen: null }
  try {
    const raw = globalThis.localStorage?.getItem(key(accountId))
    const parsed = raw ? JSON.parse(raw) as StoredShortcuts : null
    if (!parsed || typeof parsed !== 'object') return empty
    return { microphone: parseBinding(parsed.microphone), deafen: parseBinding(parsed.deafen) }
  } catch { return empty }
}
function parseBinding(value: unknown): VoiceShortcutBinding | null {
  if (!value || typeof value !== 'object') return null
  const candidate = value as Partial<VoiceShortcutBinding>
  if (typeof candidate.code !== 'string' || typeof candidate.ctrlKey !== 'boolean' || typeof candidate.altKey !== 'boolean' || typeof candidate.shiftKey !== 'boolean' || typeof candidate.metaKey !== 'boolean') return null
  const binding = candidate as VoiceShortcutBinding
  return isVoiceShortcutValid(binding) ? binding : null
}

export function saveVoiceShortcutPreferences(accountId: string, shortcuts: Record<VoiceShortcutAction, VoiceShortcutBinding | null>): void {
  try { globalThis.localStorage?.setItem(key(accountId), JSON.stringify(shortcuts)) } catch { /* private browsing keeps defaults */ }
}

