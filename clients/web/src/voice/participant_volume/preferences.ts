import { defaults, levels, decodeDocument, browserStorage, type StoredVolumes, type PreferenceStorage } from './document'
export class VoiceVolumePreferences {
  private accountId: string | null = null
  private current = new Map<string, StoredVolumes>()
  private legacy = true
  private pending: { key: string; payload: string } | null = null
  private timer: ReturnType<typeof setTimeout> | undefined
  private listeners = new Set<() => void>()
  private _status: 'success' | 'fallback' = 'success'
  private pagehide = () => this.flush()
  constructor(private readonly storage: PreferenceStorage | null = browserStorage()) {
    if (!storage) this._status = 'fallback'
    if (typeof window !== 'undefined') window.addEventListener('pagehide', this.pagehide)
  }
  get status(): 'success' | 'fallback' { return this._status }
  onStatus(listener: () => void): () => void { this.listeners.add(listener); return () => this.listeners.delete(listener) }
  private report(status: 'success' | 'fallback'): void {
    this._status = status
    this.listeners.forEach((listener) => listener())
  }
  bind(accountId: string): void {
    this.flush()
    this.accountId = accountId; this.current.clear(); this.legacy = true
    this.report(this.storage ? 'success' : 'fallback')
    try {
      const document = decodeDocument(this.storage?.getItem(this.key()!) ?? null)
      this.current = new Map(Object.entries(document.volumes)); this.legacy = document.legacy
    } catch { this.legacy = false; this.report('fallback') }
  }
  unbind(): void { this.flush(); this.accountId = null; this.current.clear(); this.legacy = true }
  dispose(): void {
    this.unbind(); this.listeners.clear()
    if (typeof window !== 'undefined') window.removeEventListener('pagehide', this.pagehide)
  }
  participant(id: string): number { return this.read(id).participant }
  screen(id: string): number { return this.read(id).screen }
  setParticipant(id: string, percent: number): void { this.write(id, { ...this.read(id), participant: levels({ participant: percent }).participant }) }
  setScreen(id: string, percent: number): void { this.write(id, { ...this.read(id), screen: levels({ screen: percent }).screen }) }
  reset(): void { this.current.clear(); this.legacy = false; this.enqueue(); this.flush() }
  private key(): string | null { return this.accountId ? `voice-volume:v2:${this.accountId}` : null }
  private read(id: string): StoredVolumes {
    const cached = this.current.get(id)
    if (cached) return cached
    let saved = defaults()
    if (this.legacy && this.accountId && this.storage) {
      try { saved = levels(JSON.parse(this.storage.getItem(`voice-volume:v1:${this.accountId}:${id}`) ?? '{}')) }
      catch { this.report('fallback') }
    }
    this.current.set(id, saved)
    return saved
  }
  private write(id: string, value: StoredVolumes): void { this.current.set(id, value); this.enqueue() }
  private enqueue(): void {
    const key = this.key()
    if (!key || !this.storage) { this.report('fallback'); return }
    this.pending = { key, payload: JSON.stringify({ version: 2, legacy: this.legacy, volumes: Object.fromEntries(this.current) }) }
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.flush(), 250)
  }
  flush(): void {
    clearTimeout(this.timer); this.timer = undefined
    const pending = this.pending; this.pending = null
    if (!pending || !this.storage) return
    try { this.storage.setItem(pending.key, pending.payload); this.report('success') }
    catch { this.report('fallback') }
  }
}
