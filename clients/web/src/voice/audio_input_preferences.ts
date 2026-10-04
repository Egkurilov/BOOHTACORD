interface PreferenceStorage {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
}
function browserStorage(): PreferenceStorage | null {
  try { return typeof localStorage === 'undefined' ? null : localStorage } catch { return null }
}

export class AudioInputPreferences {
  private accountId: string | null = null
  private selected = 'default'
  constructor(private readonly storage: PreferenceStorage | null = browserStorage()) {}
  bind(accountId: string): void {
    if (this.accountId === accountId) return
    this.accountId = accountId
    this.selected = 'default'
    try {
      const value: unknown = JSON.parse(this.storage?.getItem(this.key()) ?? '{}')
      const id = (value as { inputDeviceId?: unknown } | null)?.inputDeviceId
      if (typeof id === 'string' && id.length > 0 && id.length <= 1024) this.selected = id
    } catch { /* Corrupt or inaccessible storage uses the default input. */ }
  }
  get(): string { return this.selected }
  set(deviceId: string): boolean {
    if (!this.accountId) return false
    this.selected = deviceId
    try {
      if (!this.storage) return false
      this.storage.setItem(this.key(), JSON.stringify({ inputDeviceId: deviceId }))
      return true
    } catch { return false }
  }
  private key(): string { return `audio-input:v1:${this.accountId}` }
}
