export interface MicrophoneSettings { vadThresholdDb: number; microphoneGainPercent: number }
export const defaultMicrophoneSettings: MicrophoneSettings = { vadThresholdDb: -50, microphoneGainPercent: 100 }
function number(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.round(Math.max(min, Math.min(max, value))) : fallback
}
export function normalizeMicrophoneSettings(value: unknown): MicrophoneSettings {
  const raw = value && typeof value === 'object' ? value as Partial<MicrophoneSettings> : {}
  return { vadThresholdDb: number(raw.vadThresholdDb, -50, -70, -20), microphoneGainPercent: number(raw.microphoneGainPercent, 100, 0, 200) }
}
interface Storage { getItem(key: string): string | null; setItem(key: string, value: string): void }
export class MicrophonePreferences {
  private account: string | null = null
  constructor(private storage?: Storage) {}
  bind(account: string | null): void { this.account = account }
  private get key(): string { if (!this.account) throw new Error('Сначала войдите в аккаунт.'); return 'microphone-controls:v1:' + this.account }
  get(): MicrophoneSettings {
    try { return normalizeMicrophoneSettings(JSON.parse((this.storage ?? localStorage).getItem(this.key) ?? '{}')) }
    catch { return { ...defaultMicrophoneSettings } }
  }
  set(value: MicrophoneSettings): void { (this.storage ?? localStorage).setItem(this.key, JSON.stringify(normalizeMicrophoneSettings(value))) }
}
