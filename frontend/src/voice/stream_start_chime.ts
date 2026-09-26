import { ref, type Ref } from 'vue'

const preferenceKey = 'voice-screen-start-sound:v1'
type Storage = Pick<globalThis.Storage, 'getItem' | 'setItem'>
type ContextFactory = () => AudioContext | null

function browserStorage(): Storage | null {
  try { return typeof localStorage === 'undefined' ? null : localStorage }
  catch { return null }
}

function browserContext(): AudioContext | null {
  try { return typeof AudioContext === 'undefined' ? null : new AudioContext() }
  catch { return null }
}

export class StreamStartChime {
  readonly enabled: Ref<boolean>
  private context: AudioContext | null = null

  constructor(private readonly createContext: ContextFactory = browserContext, private readonly storage: Storage | null = browserStorage()) {
    let saved: string | null = null
    try { saved = storage?.getItem(preferenceKey) ?? null } catch {}
    this.enabled = ref(saved !== 'off')
  }

  setEnabled(enabled: boolean): void {
    this.enabled.value = enabled
    try { this.storage?.setItem(preferenceKey, enabled ? 'on' : 'off') } catch {}
  }

  activate(): void {
    if (!this.enabled.value) return
    try {
      this.context ??= this.createContext()
      if (this.context?.state === 'suspended') void this.context.resume().catch(() => undefined)
    } catch { /* Sound must never interrupt voice admission. */ }
  }

  play(): void {
    const context = this.context
    if (!this.enabled.value || !context || context.state !== 'running') return
    try {
      const oscillator = context.createOscillator()
      const gain = context.createGain()
      const start = context.currentTime
      oscillator.type = 'sine'
      oscillator.frequency.value = 880
      gain.gain.setValueAtTime(0.0001, start)
      gain.gain.exponentialRampToValueAtTime(0.045, start + 0.015)
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.18)
      oscillator.connect(gain)
      gain.connect(context.destination)
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect() }
      oscillator.start(start)
      oscillator.stop(start + 0.19)
    } catch { /* Browser media policy leaves the visual notice available. */ }
  }
}
