import { AudioMixer, normalizeAudioVolume, type AudioGainHandle } from './audio_gain'
import { createScreenReceiverReader } from './screen_receiver_reader'
import { ScreenTrackAttachment } from './screen_track_attachment'
import type { ScreenViewerCard, ScreenViewerStream } from './screen_viewer_types'
import { validScreenThumbnail } from './screen_thumbnail'
export type { ScreenViewerCard, ScreenViewerPublication, ScreenViewerStream, ScreenViewerTrack } from './screen_viewer_types'

export class ScreenViewerController {
  private audio: HTMLAudioElement | null = null
  private audioOutput: AudioGainHandle | null = null
  private audioVolume = 100
  private readonly attachedAudio = new ScreenTrackAttachment()
  private readonly attachedVideo = new ScreenTrackAttachment()
  private screenAudioMuted = false
  private deafened = false
  private hasEnded = false
  private readonly listeners = new Set<() => void>()
  private readonly receiverReader = createScreenReceiverReader()
  private resumeParticipantId: string | null = null
  private readonly thumbnailUrls = new Map<string, string>()
  private selected: ScreenViewerStream | null = null
  private video: HTMLVideoElement | null = null

  constructor(private readonly source: () => ScreenViewerStream[], private readonly mixer: Pick<AudioMixer, 'attach'> = new AudioMixer()) {}

  get selectedId(): string | null { return this.selected?.id ?? null }
  get selectedAccountId(): string | null { return this.selected?.accountId ?? null }
  get ended(): boolean { return this.hasEnded }
  get audioMuted(): boolean { return this.screenAudioMuted }
  hasAttachedVideo(element:HTMLVideoElement|null):boolean {return this.attachedVideo.matches(this.selected?.video.track??null,element)}

  cards(): ScreenViewerCard[] {
    return this.source().map(({ accountId, hasAudio, id, isLocal, participantId, participantName, targetProfile, video }) => ({
      accountId, hasAudio, id, isLocal, participantId, participantName, targetProfile,
      ...(this.thumbnailUrls.get(participantId) ? { thumbnailUrl: this.thumbnailUrls.get(participantId) } : {}),
      ...(!isLocal && video.track?.getReceiverStats ? { readReceiverStats: this.receiverReader(video.track) } : {}),
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
    this.resumeParticipantId = null
    for (const url of this.thumbnailUrls.values()) URL.revokeObjectURL(url)
    this.thumbnailUrls.clear()
    this.select(null, this.video, this.audio)
  }

  setThumbnail(participantId: string, bytes: Uint8Array): void {
    if (!participantId || !validScreenThumbnail(bytes)) return
    const previous = this.thumbnailUrls.get(participantId)
    if (previous) URL.revokeObjectURL(previous)
    this.thumbnailUrls.set(participantId, URL.createObjectURL(new Blob([bytes as BlobPart], { type: 'image/jpeg' })))
    this.notify()
  }

  removeThumbnail(participantId: string): void {
    const previous = this.thumbnailUrls.get(participantId)
    if (!previous) return
    URL.revokeObjectURL(previous)
    this.thumbnailUrls.delete(participantId)
    this.notify()
  }

  reconcile(): void {
    const current = this.selected && this.source().find((stream) => stream.id === this.selected!.id)
    if (this.selected && !current) {
      const wasLocal = this.selected.isLocal === true
      this.detachAndUnsubscribe()
      this.selected = null
      this.hasEnded = !wasLocal
      if (wasLocal) this.resumeParticipantId = null
    } else if (!this.selected && this.resumeParticipantId) {
      const restarted = this.source().find((stream) => stream.participantId === this.resumeParticipantId)
      if (restarted) {
        this.select(restarted.id, this.video, this.audio)
        return
      }
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
    this.resumeParticipantId = next?.participantId ?? null
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
    this.attachedVideo.update(this.selected.video.track ?? null, this.video)
    this.attachedAudio.update(this.selected.audio?.track ?? null, this.audio)
  }

  private detachAndUnsubscribe(): void {
    this.audioOutput?.dispose()
    this.audioOutput = null
    if (!this.selected) return
    this.attachedVideo.clear()
    this.attachedAudio.clear()
    this.selected.video.setSubscribed?.(false)
    this.selected.audio?.setSubscribed?.(false)
  }

  private notify(): void {
    this.listeners.forEach((listener) => listener())
  }
}
