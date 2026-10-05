export type NotificationMode = 'all' | 'mentions' | 'none'
export type ConversationKind = 'CHANNEL' | 'DIRECT_MESSAGE'
export interface Preference { mode: NotificationMode; pausedUntil: number }
export const DEFAULT: Preference = { mode: 'all', pausedUntil: 0 }
export function validPreference(value: unknown): value is Preference {
  if (!value || typeof value !== 'object') return false
  const candidate = value as Preference
  return ['all','mentions','none'].includes(candidate.mode) && Number.isSafeInteger(candidate.pausedUntil) && candidate.pausedUntil >= 0
}
export function notificationAllowed(preference: Preference, mentioned: boolean, now: number): boolean {
  return preference.pausedUntil <= now && (preference.mode === 'all' || (preference.mode === 'mentions' && mentioned))
}
