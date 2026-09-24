import { AudioMixer, type AudioGainHandle } from './audio_gain'

export interface RemoteVoiceTrack {
  attach(element: HTMLAudioElement): HTMLMediaElement
  detach(element: HTMLAudioElement): HTMLMediaElement[]
}

export interface RemoteVoiceCard {
  accountId: string | null
  id: string
  name: string | undefined
  speaking: boolean
}

interface AttachedVoice {
  card: RemoteVoiceCard
  element: HTMLAudioElement
  output: AudioGainHandle
  track: RemoteVoiceTrack
}

export class RemoteVoicePlayback {
  private deafened = false
  private readonly attached = new Map<string, AttachedVoice>()
  private readonly listeners = new Set<() => void>()
  private readonly speaking = new Map<string, boolean>()
  private readonly volumes = new Map<string, number>()

  constructor(
    private readonly createElement: () => HTMLAudioElement = () => document.createElement('audio'),
    private readonly append: (element: HTMLAudioElement) => void = (element) => document.body.appendChild(element),
    private readonly mixer: Pick<AudioMixer, 'attach'> = new AudioMixer(),
  ) {}

  attach(participantId: string, track: RemoteVoiceTrack, name?: string, accountId: string | null = null): void {
    this.detach(participantId)
    const element = this.createElement()
    element.autoplay = true
    const output = this.mixer.attach(element)
    output.setMuted(this.deafened)
    output.setVolume(this.volumes.get(participantId) ?? 100)
    track.attach(element)
    this.append(element)
    this.attached.set(participantId, { card: { accountId, id: participantId, name, speaking: this.speaking.get(participantId) ?? false }, element, output, track })
    this.notify()
  }

  clear(): void { [...this.attached.keys()].forEach((participantId) => this.detach(participantId)) }

  detach(participantId: string): void {
    const current = this.attached.get(participantId)
    if (!current) return
    current.output.dispose()
    current.track.detach(current.element)
    current.element.remove()
    this.attached.delete(participantId)
    this.notify()
  }

  forget(participantId: string): void {
    this.detach(participantId)
    this.speaking.delete(participantId)
    this.volumes.delete(participantId)
  }

  cards(): RemoteVoiceCard[] { return [...this.attached.values()].map(({ card }) => card) }

  onChange(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  setDeafened(deafened: boolean): void {
    this.deafened = deafened
    this.attached.forEach(({ output }) => output.setMuted(deafened))
  }

  setSpeaking(participantId: string, speaking: boolean): void {
    if (this.speaking.get(participantId) === speaking) return
    this.speaking.set(participantId, speaking)
    const current = this.attached.get(participantId)
    if (current) current.card.speaking = speaking
    this.notify()
  }

  isSpeaking(participantId: string): boolean {
    return this.speaking.get(participantId) ?? false
  }

  setVolume(participantId: string, percent: number): void {
    this.volumes.set(participantId, percent)
    this.attached.get(participantId)?.output.setVolume(percent)
  }

  private notify(): void {
    this.listeners.forEach((listener) => listener())
  }
}
