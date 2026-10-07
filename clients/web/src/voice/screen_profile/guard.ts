import { inspectScreenProfile } from './inspect'
import type { ScreenProfile } from './policy'
import { sameBinding, trackBinding, type ProfileSnapshot, type ProfileTrack } from './types'
import { screenSenderStatsSampler } from '../screen_stats_sampler'

export class ScreenProfileGuard {
  snapshot?: ProfileSnapshot
  private profile: ScreenProfile | null = null
  private generation = 0
  private nextCheck = 0
  private checking = false
  private driftChecks = 0
  private terminal = false
  private suspended = false
  private binding?: ReturnType<typeof trackBinding>
  private frames = new Map<string, number>()
  constructor(private readonly readTrack: () => ProfileTrack | undefined) {}

  adopt(profile: ScreenProfile): void {
    const track = this.readTrack()
    if (!track || track.mediaStreamTrack.readyState !== 'live') return
    ++this.generation; this.profile = profile; this.binding = trackBinding(track); this.driftChecks = 0; this.terminal = false; this.suspended = false
    this.frames.clear(); this.nextCheck = 0
    this.snapshot = { status: 'checking', reason: 'none', attempts: 0 }
  }

  stop(): void {
    ++this.generation
    if (this.binding?.sender) screenSenderStatsSampler.clear(this.binding.sender)
    this.profile = null; this.binding = undefined; this.snapshot = undefined; this.frames.clear(); this.driftChecks = 0; this.terminal = false; this.suspended = false
  }

  suspend(): void { if (this.profile && !this.suspended) { this.suspended = true; ++this.generation } }

  resume(): void {
    if (!this.profile || !this.suspended) return
    this.suspended = false; ++this.generation
    const track = this.readTrack(), attempts = this.snapshot?.attempts ?? 0
    this.driftChecks = 0; this.frames.clear(); this.nextCheck = 0
    if (!track || track.mediaStreamTrack.readyState !== 'live') {
      this.snapshot = { status: 'checking', reason: 'unavailable', attempts }; return
    }
    if (this.binding?.sender && this.binding.sender !== track.sender) screenSenderStatsSampler.clear(this.binding.sender)
    this.binding = trackBinding(track); this.terminal = this.snapshot?.status === 'failed'
    this.snapshot = { status: 'checking', reason: 'none', attempts }
  }

  async check(): Promise<void> {
    if (!this.profile || this.suspended || this.terminal || this.checking || performance.now() < this.nextCheck) return
    const track = this.readTrack()
    if (!track || track.mediaStreamTrack.readyState !== 'live') { this.stop(); return }
    if (!this.binding || !sameBinding(track, this.binding)) {
      ++this.generation; this.binding = trackBinding(track); this.frames.clear()
      this.snapshot = { status: 'checking', reason: 'none', attempts: 0 }; return
    }
    const generation = this.generation, binding = this.binding, profile = this.profile
    const current = () => generation === this.generation && sameBinding(this.readTrack(), binding)
    this.checking = true; this.nextCheck = performance.now() + 5000
    try {
      const frames = new Map(this.frames), result = await inspectScreenProfile(track, profile, frames)
      if (!current()) return
      this.frames = frames
      if (result.status === 'drift') {
        this.driftChecks++
        const status = this.driftChecks < 3 ? 'checking' : this.snapshot?.attempts ? 'failed' : 'drift'
        this.terminal = status === 'failed'
        this.snapshot = { ...result, status, attempts: this.snapshot?.attempts ?? 0 }
      } else {
        this.driftChecks = 0; this.snapshot = { ...result, attempts: this.snapshot?.attempts ?? 0 }
      }
    } catch {
      if (current()) this.snapshot = { status: 'checking', reason: 'unavailable', attempts: 0 }
    } finally { this.checking = false }
  }

  async repair(profile: ScreenProfile, reconcile: () => Promise<void>, operationCurrent: () => boolean): Promise<boolean> {
    const track = this.readTrack(), binding = this.binding, generation = this.generation
    if (this.suspended || this.snapshot?.status !== 'drift' || this.snapshot.attempts > 0 || this.profile !== profile || !track || !binding) return false
    const operationCurrentForRepair = () => generation === this.generation && operationCurrent()
    const captureIsBound = () => sameCapture(this.readTrack(), binding)
    if (!operationCurrentForRepair() || !captureIsBound()) return false
    const previous = this.snapshot, reason = this.snapshot.reason
    this.snapshot = { ...this.snapshot, status: 'repairing', attempts: 1 }
    try {
      await reconcile()
      const rebound = this.readTrack()
      if (!rebound || !operationCurrentForRepair() || !sameCapture(rebound, binding)) throw new Error('Публикация демонстрации не восстановлена.')
      this.binding = trackBinding(rebound); this.driftChecks = 0; this.frames.clear()
      this.snapshot = { status: 'checking', reason: 'none', attempts: 1 }
      return true
    } catch (cause) {
      if (generation === this.generation && operationCurrent()) { this.snapshot = { status: 'failed', reason, attempts: 1 }; this.terminal = true }
      else if (generation === this.generation) this.snapshot = previous
      throw cause
    }
  }
}

function sameCapture(track: ProfileTrack | undefined, binding: ReturnType<typeof trackBinding>): boolean {
  return track === binding.track && track.mediaStreamTrack === binding.capture && binding.capture.readyState === 'live'
}
