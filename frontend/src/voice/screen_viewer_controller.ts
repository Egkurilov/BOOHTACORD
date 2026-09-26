import { AudioMixer, normalizeAudioVolume, type AudioGainHandle } from './audio_gain'
import type { ScreenViewerCard, ScreenViewerStream } from './screen_viewer_types'
export type { ScreenViewerCard, ScreenViewerPublication, ScreenViewerStream, ScreenViewerTrack } from './screen_viewer_types'

export class ScreenViewerController {
  private audio: HTMLAudioElement | null = null
  private audioOutput: AudioGainHandle | null = null
  private audioVolume = 100
  private screenAudioMuted = false
  private deafened = false
  private hasEnded = false
  private readonly listeners = new Set<() => void>()
  private selected: ScreenViewerStream | null = null
  private video: HTMLVideoElement | null = null

  constructor(private readonly source: () => ScreenViewerStream[], private readonly mixer: Pick<AudioMixer, 'attach'> = new AudioMixer()) {}

  get selectedId(): string | null { return this.selected?.id ?? null }
  get selectedAccountId(): string | null { return this.selected?.accountId ?? null }
  get ended(): boolean { return this.hasEnded }
  get audioMuted(): boolean { return this.screenAudioMuted }

  cards(): ScreenViewerCard[] {
    return this.source().map(({ accountId, hasAudio, id, isLocal, participantId, participantName, video }) => ({
      accountId, hasAudio, id, isLocal, participantId, participantName,
      ...(!isLocal && video.track?.getReceiverStats ? { readReceiverStats: () => video.track!.getReceiverStats!() } : {}),
    }))
  }

  onChange(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  setDeafened(deafened: boolean): void {
    this.deafened = deafened
    this.audioOutput?.setMuted(deafened || this.screenAudioMuted)
  }

  setAudioMuted(muted: boolean): void {
    this.screenAudioMuted = muted
    this.audioOutput?.setMuted(this.deafened || muted)
    this.notify()
  }

  setAudioVolume(percent: number): void {
    this.audioVolume = normalizeAudioVolume(percent)
    this.audioOutput?.setVolume(this.audioVolume)
  }

  clear(): void {
    this.select(null, this.video, this.audio)
  }

  reconcile(): void {
    const current = this.selected && this.source().find((stream) => stream.id === this.selected!.id)
    if (this.selected && !current) {
      this.detachAndUnsubscribe()
      this.selected = null
      this.hasEnded = true
    } else if (current && (current.video !== this.selected?.video || current.audio !== this.selected?.audio)) {
      this.select(current.id, this.video, this.audio)
      return
    } else {
      if (current) this.selected = current
      this.attachSelected()
    }
    this.notify()
  }

  select(id: string | null, video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void {
    const next = id === null ? null : this.source().find((stream) => stream.id === id)
    if (id !== null && !next) throw new Error('Недоступная демонстрация в текущем голосовом канале.')
    this.detachAndUnsubscribe()
    this.hasEnded = false
    this.selected = next ?? null
    this.video = video
    this.audio = audio
    if (this.selected?.audio && this.audio) {
      this.audioOutput = this.mixer.attach(this.audio)
      this.audioOutput.setMuted(this.deafened || this.screenAudioMuted)
      this.audioOutput.setVolume(this.audioVolume)
    }
    if (this.selected) {
      this.selected.video.setSubscribed?.(true)
      this.selected.audio?.setSubscribed?.(true)
      this.attachSelected()
    }
    this.notify()
  }

  private attachSelected(): void {
    if (!this.selected) return
    if (this.video) this.selected.video.track?.attach(this.video)
    if (this.audio) this.selected.audio?.track?.attach(this.audio)
  }

  private detachAndUnsubscribe(): void {
    this.audioOutput?.dispose()
    this.audioOutput = null
    if (!this.selected) return
    if (this.video) this.selected.video.track?.detach(this.video)
    if (this.audio) this.selected.audio?.track?.detach(this.audio)
    this.selected.video.setSubscribed?.(false)
    this.selected.audio?.setSubscribed?.(false)
  }

  private notify(): void {
    this.listeners.forEach((listener) => listener())
  }
}
