import { type LocalVideoTrack, type Room } from 'livekit-client'
import { createDisplayCapture, createSyntheticCapture } from './capture'
import { BaselinePresentation } from './presentation'
import { collectSamples, sampleSender } from './stats'
import { connectBaselineRoom } from './connection'
import { publishBaselineCapture } from './publish'

type Role = 'publisher' | 'viewer'
type Credentials = { url: string; token: string; role: Role }

export class ScreenBaselineSession {
  private credentials: Credentials | null = null
  private room: Room | null = null
  private localTrack: LocalVideoTrack | null = null
  private capture: MediaStream | null = null
  private stopSynthetic: (() => void) | null = null
  private source = 'none'
  private generatedFrames = 0
  private generationStartedAt = 0
  private readonly presentation = new BaselinePresentation()

  configure(credentials: Credentials) { this.credentials = credentials }

  async connect() {
    if (!this.credentials || this.room) throw new Error('baseline session is not ready')
    await connectBaselineRoom(this.credentials, this.presentation, room => { this.room = room }, value => this.setStatus(value))
    this.credentials.token = ''
    this.setStatus('connected')
  }

  async startSynthetic() {
    if (this.credentials?.role !== 'publisher') throw new Error('publisher role required')
    this.source = 'synthetic-moving-canvas'
    this.generatedFrames = 0
    this.generationStartedAt = performance.now()
    const capture = createSyntheticCapture(frame => { this.generatedFrames = frame })
    this.stopSynthetic = capture.stop
    await this.publish(capture.stream)
  }

  async startDisplayCapture() {
    if (this.credentials?.role !== 'publisher') throw new Error('publisher role required')
    this.source = 'user-selected-display-capture'
    try {
      await this.publish(await createDisplayCapture())
    } catch {
      this.setStatus('display-capture-failed-or-cancelled')
      throw new Error('Display capture failed or was cancelled.')
    }
  }

  private async publish(stream: MediaStream) {
    if (!this.room || this.credentials?.role !== 'publisher') throw new Error('publisher room required')
    this.capture = stream
    try {
      this.localTrack = await publishBaselineCapture(this.room, stream, () => {
        this.setStatus('capture-ended'); if (this.room) void this.stop()
      })
      this.setStatus('publishing-one-video-layer')
    } catch {
      this.setStatus('publish-failed')
      await this.stop()
      throw new Error('Video publish failed; no track data was written to the report.')
    }
  }

  waitForFirstFrame(timeoutMs: number) { return this.presentation.waitForFirstFrame(timeoutMs) }

  async snapshot() {
    const settings = this.capture?.getVideoTracks()[0]?.getSettings()
    return {
      monotonicMs: performance.now(), role: this.credentials?.role ?? 'unknown', source: this.source,
      captureSettings: settings ? { width: settings.width ?? null, height: settings.height ?? null, frameRate: settings.frameRate ?? null } : null,
      generatedFrames: this.generatedFrames,
      generatedFrameElapsedMs: this.generationStartedAt ? performance.now() - this.generationStartedAt : null,
      outbound: await sampleSender(this.localTrack), ...this.presentation.snapshot(), userAgent: navigator.userAgent,
      visibilityState: document.visibilityState,
    }
  }

  collectSamples(durationMs: number, intervalMs: number) {
    return collectSamples(() => this.snapshot(), durationMs, intervalMs)
  }

  async stop() {
    const room = this.room
    this.room = null
    this.stopSynthetic?.()
    this.stopSynthetic = null
    this.presentation.stop()
    if (this.localTrack && room) await room.localParticipant.unpublishTrack(this.localTrack, true).catch(() => undefined)
    this.localTrack?.stop()
    this.localTrack = null
    this.capture?.getTracks().forEach(track => track.stop())
    this.capture = null
    await room?.disconnect(true)
    this.setStatus('stopped')
  }

  private setStatus(value: string) {
    const status = document.querySelector<HTMLElement>('#status')
    if (status) status.textContent = value
  }
}
