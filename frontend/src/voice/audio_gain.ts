export interface AudioGainHandle {
  dispose(): void
  setMuted(muted: boolean): void
  setVolume(percent: number): void
}

interface ConnectableAudioNode {
  connect(destination: unknown): unknown
  disconnect(): void
}

interface GainAudioNode extends ConnectableAudioNode {
  gain: { value: number }
}

export interface AudioContextLike {
  createGain(): GainAudioNode
  createMediaElementSource(element: HTMLMediaElement): ConnectableAudioNode
  destination: unknown
}

export type AudioContextFactory = () => AudioContextLike | null

export function normalizeAudioVolume(percent: number): number {
  return Math.max(0, Math.min(200, Math.round(Number.isFinite(percent) ? percent : 100)))
}

function browserContext(): AudioContextLike | null {
  if (typeof AudioContext === 'undefined') return null
  return new AudioContext() as unknown as AudioContextLike
}

abstract class BaseAudioGain implements AudioGainHandle {
  protected muted = false
  protected volume = 100

  constructor(protected readonly element: HTMLAudioElement) {}

  setMuted(muted: boolean): void {
    this.muted = muted
    this.apply()
  }

  setVolume(percent: number): void {
    this.volume = normalizeAudioVolume(percent)
    this.apply()
  }

  abstract dispose(): void
  protected abstract apply(): void
}

class ElementAudioGain extends BaseAudioGain {
  dispose(): void {}

  protected apply(): void {
    this.element.muted = this.muted
    this.element.volume = Math.min(1, this.volume / 100)
  }
}

class WebAudioGain extends BaseAudioGain {
  constructor(element: HTMLAudioElement, private readonly source: ConnectableAudioNode, private readonly gain: GainAudioNode) {
    super(element)
    this.apply()
  }

  dispose(): void {
    this.source.disconnect()
    this.gain.disconnect()
  }

  protected apply(): void {
    this.element.muted = false
    this.element.volume = 1
    this.gain.gain.value = this.muted ? 0 : this.volume / 100
  }
}

export class AudioMixer {
  private context: AudioContextLike | null | undefined
  private readonly sources = new WeakMap<HTMLAudioElement, ConnectableAudioNode>()

  constructor(private readonly createContext: AudioContextFactory = browserContext) {}

  attach(element: HTMLAudioElement): AudioGainHandle {
    this.context ??= this.createContext()
    if (!this.context) return new ElementAudioGain(element)
    try {
      const gain = this.context.createGain()
      const source = this.sources.get(element) ?? this.context.createMediaElementSource(element)
      source.connect(gain)
      gain.connect(this.context.destination)
      this.sources.set(element, source)
      return new WebAudioGain(element, source, gain)
    } catch {
      return new ElementAudioGain(element)
    }
  }
}
