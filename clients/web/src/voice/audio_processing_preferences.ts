import { normalizeAudioProcessing } from './noise_suppression/types'
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
      return normalizeAudioProcessing(value)
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
