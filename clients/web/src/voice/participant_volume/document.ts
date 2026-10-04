import { normalizeAudioVolume } from '../audio_gain'
export interface StoredVolumes { participant: number; screen: number }
export interface VolumeDocument { version: 2; legacy: boolean; volumes: Record<string, StoredVolumes> }
export const defaults = (): StoredVolumes => ({ participant: 100, screen: 100 })
export function levels(value: unknown): StoredVolumes {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return defaults()
  const saved = value as Partial<StoredVolumes>
  return { participant: normalizeAudioVolume(saved.participant ?? 100), screen: normalizeAudioVolume(saved.screen ?? 100) }
}
export function decodeDocument(raw: string | null): VolumeDocument {
  if (raw === null) return { version: 2, legacy: true, volumes: {} }
  const value = JSON.parse(raw) as Partial<VolumeDocument> | null
  if (!value || value.version !== 2 || typeof value.legacy !== 'boolean' || !value.volumes || typeof value.volumes !== 'object' || Array.isArray(value.volumes)) throw new Error('Invalid volume document')
  return { version: 2, legacy: value.legacy, volumes: Object.fromEntries(Object.entries(value.volumes).map(([id, value]) => [id, levels(value)])) }
}
export interface PreferenceStorage { getItem(key: string): string | null; setItem(key: string, value: string): void }
export function browserStorage(): PreferenceStorage | null {
  try { return typeof localStorage === 'undefined' ? null : localStorage } catch { return null }
}
