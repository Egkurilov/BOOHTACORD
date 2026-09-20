import { normalizeAudioVolume } from './audio_gain'

interface PreferenceStorage {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
}

interface StoredVolumes {
  participant: number
  screen: number
}

function browserStorage(): PreferenceStorage | null {
  try {
    return typeof localStorage === 'undefined' ? null : localStorage
  } catch {
    return null
  }
}

export class VoiceVolumePreferences {
  private accountId: string | null = null

  constructor(private readonly storage: PreferenceStorage | null = browserStorage()) {}

  bind(accountId: string): void {
    this.accountId = accountId
  }

  participant(remoteAccountId: string): number {
    return this.read(remoteAccountId).participant
  }

  screen(remoteAccountId: string): number {
    return this.read(remoteAccountId).screen
  }

  setParticipant(remoteAccountId: string, percent: number): void {
    this.write(remoteAccountId, { ...this.read(remoteAccountId), participant: normalizeAudioVolume(percent) })
  }

  setScreen(remoteAccountId: string, percent: number): void {
    this.write(remoteAccountId, { ...this.read(remoteAccountId), screen: normalizeAudioVolume(percent) })
  }

  private key(remoteAccountId: string): string | null {
    return this.accountId ? `voice-volume:v1:${this.accountId}:${remoteAccountId}` : null
  }

  private read(remoteAccountId: string): StoredVolumes {
    const key = this.key(remoteAccountId)
    if (!key || !this.storage) return { participant: 100, screen: 100 }
    try {
      const value: unknown = JSON.parse(this.storage.getItem(key) ?? '{}')
      if (typeof value !== 'object' || value === null || Array.isArray(value)) return { participant: 100, screen: 100 }
      const stored = value as Partial<StoredVolumes>
      return { participant: normalizeAudioVolume(stored.participant ?? 100), screen: normalizeAudioVolume(stored.screen ?? 100) }
    } catch {
      return { participant: 100, screen: 100 }
    }
  }

  private write(remoteAccountId: string, volumes: StoredVolumes): void {
    const key = this.key(remoteAccountId)
    if (!key || !this.storage) return
    try {
      this.storage.setItem(key, JSON.stringify(volumes))
    } catch {}
  }
}
