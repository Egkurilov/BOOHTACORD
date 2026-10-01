import { defaultAudioProcessing, type AudioProcessingOptions } from './livekit_gateway'

interface PreferenceStorage {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
}

function browserStorage(): PreferenceStorage | null {
  try {
    return typeof localStorage === 'undefined' ? null : localStorage
  } catch {
    return null
  }
}

function isAudioProcessingOptions(value: unknown): value is AudioProcessingOptions {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false
  const candidate = value as Partial<AudioProcessingOptions>
  return typeof candidate.autoGainControl === 'boolean' && typeof candidate.echoCancellation === 'boolean' && typeof candidate.noiseSuppression === 'boolean'
}

export class AudioProcessingPreferences {
  private accountId: string | null = null

  constructor(private readonly storage: PreferenceStorage | null = browserStorage()) {}

  bind(accountId: string): void { this.accountId = accountId }
  clear(): void { this.accountId = null }

  get(): AudioProcessingOptions {
    const key = this.key()
    if (!key || !this.storage) return { ...defaultAudioProcessing }
    try {
      const value: unknown = JSON.parse(this.storage.getItem(key) ?? '{}')
      return isAudioProcessingOptions(value) ? { ...value } : { ...defaultAudioProcessing }
    } catch {
      return { ...defaultAudioProcessing }
    }
  }

  set(next: AudioProcessingOptions): void {
    const key = this.key()
    if (!key || !this.storage) return
    try { this.storage.setItem(key, JSON.stringify(next)) } catch {}
  }

  private key(): string | null { return this.accountId ? `audio-processing:v1:${this.accountId}` : null }
}
