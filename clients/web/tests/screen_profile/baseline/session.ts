import { type RemoteTrack, type Room } from 'livekit-client'
import { BaselinePresentation } from './presentation'
import { collectSamples, sampleReceiver } from './stats'
import { connectBaselineRoom } from './connection'
import { baselinePlan } from './settings'
import { BaselinePublisher } from './publisher'

type Role = 'publisher' | 'viewer'
type Credentials = { url: string; token: string; role: Role; numberedSynthetic?: boolean }

export class ScreenBaselineSession {
  private credentials: Credentials | null = null
  private room: Room | null = null
  private remoteTrack: RemoteTrack | null = null
  private source = 'none'
  private visibilityRevision = 0
  private readonly presentation = new BaselinePresentation()
  private readonly publisher: BaselinePublisher

  constructor() {
    this.publisher = new BaselinePublisher(
      () => this.room, () => this.credentials?.role, value => this.setStatus(value),
      async () => { this.setStatus('capture-ended'); await this.stop() },
    )
    document.addEventListener('visibilitychange', () => this.visibilityRevision++)
  }

  configure(credentials: Credentials) {
    this.credentials = credentials
    if (credentials.role === 'viewer') this.source = credentials.numberedSynthetic ? 'synthetic-moving-canvas' : 'remote-display-or-unknown'
  }

  async connect() {
    if (!this.credentials || this.room) throw new Error('baseline session is not ready')
    const credentials = this.credentials
    try {
      await connectBaselineRoom(credentials, this.presentation, room => { this.room = room }, value => this.setStatus(value), track => { this.remoteTrack = track })
      this.setStatus('connected')
    } catch (error) {
      await this.stop()
      this.setStatus('connect-failed')
      throw error
    } finally {
      credentials.token = ''
    }
  }

  startSynthetic(captureFps = 60) { return this.publisher.startSynthetic(captureFps) }
  startDisplayCapture() { return this.publisher.startDisplayCapture() }

  waitForFirstFrame(timeoutMs: number) { return this.presentation.waitForFirstFrame(timeoutMs) }

  async snapshot() {
    const publication = await this.publisher.snapshot()
    return {
      ...publication,
      monotonicMs: performance.now(), role: this.credentials?.role ?? 'unknown',
      source: this.credentials?.role === 'publisher' ? publication.source : this.source,
      baselineProfileId: baselinePlan.profileId,
      visibilityRevision: this.visibilityRevision,
      inbound: await sampleReceiver(this.remoteTrack), ...this.presentation.snapshot(), userAgent: navigator.userAgent,
      visibilityState: document.visibilityState,
    }
  }

  collectSamples(durationMs: number, intervalMs: number) {
    return collectSamples(() => this.snapshot(), durationMs, intervalMs)
  }

  async stop() {
    const room = this.room
    this.room = null
    this.presentation.stop()
    await this.publisher.stop(room)
    this.remoteTrack = null
    await room?.disconnect(true)
    if (this.credentials) this.credentials.token = ''
    this.credentials = null
    this.setStatus('stopped')
  }

  private setStatus(value: string) {
    const status = document.querySelector<HTMLElement>('#status')
    if (status) status.textContent = value
  }
}
