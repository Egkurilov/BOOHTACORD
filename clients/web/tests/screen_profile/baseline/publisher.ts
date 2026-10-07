import type { Room, LocalVideoTrack } from 'livekit-client'
import { createDisplayCapture, createSyntheticCapture } from './capture'
import { publishBaselineCapture } from './publish'
import { sampleSender } from './stats'
import { baselinePlan } from './settings'

type Role = 'publisher' | 'viewer' | undefined

export class BaselinePublisher {
  private track: LocalVideoTrack | null = null
  private capture: MediaStream | null = null
  private stopSynthetic: (() => void) | null = null
  private source = 'none'
  private generatedFrames = 0
  private requestedSyntheticFps: number | null = null
  private generationStartedAt = 0

  constructor(
    private readonly room: () => Room | null,
    private readonly role: () => Role,
    private readonly setStatus: (value: string) => void,
    private readonly onCaptureEnded: () => Promise<void>,
  ) {}

  async startSynthetic(captureFps = baselinePlan.frameRate) {
    this.assertPublisher()
    this.source = 'synthetic-moving-canvas'
    this.requestedSyntheticFps = captureFps
    this.generatedFrames = 0
    this.generationStartedAt = performance.now()
    const capture = createSyntheticCapture(frame => { this.generatedFrames = frame }, captureFps)
    this.stopSynthetic = capture.stop
    await this.publish(capture.stream)
  }

  async startDisplayCapture() {
    this.assertPublisher()
    this.source = 'user-selected-display-capture'
    try {
      await this.publish(await createDisplayCapture())
    } catch {
      this.setStatus('display-capture-failed-or-cancelled')
      throw new Error('Display capture failed or was cancelled.')
    }
  }

  private assertPublisher() {
    if (this.role() !== 'publisher') throw new Error('publisher role required')
  }

  private async publish(stream: MediaStream) {
    const room = this.room()
    if (!room || this.role() !== 'publisher') throw new Error('publisher room required')
    this.capture = stream
    try {
      this.track = await publishBaselineCapture(room, stream, this.onCaptureEnded)
      this.setStatus('publishing-one-video-layer')
    } catch {
      this.setStatus('publish-failed')
      await this.onCaptureEnded()
      throw new Error('Video publish failed; no track data was written to the report.')
    }
  }

  async snapshot() {
    const settings = this.capture?.getVideoTracks()[0]?.getSettings()
    return {
      source: this.source,
      captureSettings: settings ? { width: settings.width ?? null, height: settings.height ?? null, frameRate: settings.frameRate ?? null } : null,
      generatedFrames: this.generatedFrames,
      requestedSyntheticFps: this.requestedSyntheticFps,
      generatedFrameElapsedMs: this.generationStartedAt ? performance.now() - this.generationStartedAt : null,
      outbound: await sampleSender(this.track),
    }
  }

  async stop(room: Room | null) {
    this.stopSynthetic?.()
    this.stopSynthetic = null
    if (this.track && room) await room.localParticipant.unpublishTrack(this.track, true).catch(() => undefined)
    this.track?.stop()
    this.track = null
    this.capture?.getTracks().forEach(track => track.stop())
    this.capture = null
  }
}
