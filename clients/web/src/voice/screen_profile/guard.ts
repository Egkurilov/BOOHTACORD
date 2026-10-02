import { applyScreenProfile } from './apply'
import { inspectScreenProfile } from './inspect'
import type { ScreenProfile } from './policy'
import { abortProfile, sameBinding, trackBinding, type ProfileSnapshot, type ProfileTrack } from './types'

export class ScreenProfileGuard {
  snapshot?: ProfileSnapshot
  private profile: ScreenProfile | null = null
  private generation = 0
  private nextCheck = 0
  private failures = 0
  private checking = false
  private applying = 0
  private terminal = false
  private binding?: ReturnType<typeof trackBinding>
  private frames = new Map<string, number>()
  private queue = Promise.resolve()
  constructor(private readonly readTrack: () => ProfileTrack | undefined) {}

  private serialize(action: () => Promise<void>): Promise<void> {
    const next = this.queue.then(action)
    this.queue = next.catch(() => {})
    return next
  }

  async apply(profile: ScreenProfile): Promise<void> {
    const generation = ++this.generation
    this.applying++
    try {
      await this.serialize(async () => {
        const track = this.readTrack()
        if (!track || generation !== this.generation) throw abortProfile()
        const binding = trackBinding(track)
        const current = () => generation === this.generation && sameBinding(this.readTrack(), binding)
        await applyScreenProfile(track, profile, current)
        if (!current()) throw abortProfile()
        this.profile = profile
        this.reset(binding)
      })
    } finally { this.applying-- }
  }

  private reset(binding: ReturnType<typeof trackBinding>): void {
    this.binding = binding
    this.failures = 0
    this.terminal = false
    this.frames.clear()
    this.nextCheck = performance.now() + 5000
    this.snapshot = { status: 'checking', reason: 'none', attempts: 0 }
  }

  stop(): void {
    this.generation++
    this.profile = null
    this.binding = undefined
    this.snapshot = undefined
    this.frames.clear()
  }

  async check(): Promise<void> {
    if (!this.profile || this.checking || this.applying || performance.now() < this.nextCheck) return
    const track = this.readTrack()
    if (!track || track.mediaStreamTrack.readyState !== 'live') { this.stop(); return }
    if (!this.binding || !sameBinding(track, this.binding)) { this.generation++; this.reset(trackBinding(track)); return }
    const generation = this.generation, binding = this.binding, profile = this.profile
    const current = () => generation === this.generation && sameBinding(this.readTrack(), binding)
    this.checking = true
    this.nextCheck = performance.now() + 5000
    try {
      const frames = new Map(this.frames)
      const result = await inspectScreenProfile(track, profile, frames)
      if (!current()) return
      this.frames = frames
      const attempts = this.snapshot?.attempts ?? 0
      this.snapshot = { ...result, attempts, ...(this.terminal ? { status: 'failed' as const, reason: this.snapshot?.reason ?? result.reason } : {}) }
      if (this.terminal) return
      this.failures = result.status === 'drift' ? this.failures + 1 : 0
      if (this.failures < 3) return
      if (attempts) { this.snapshot.status = 'failed'; this.terminal = true; return }
      this.snapshot = { ...result, status: 'repairing', attempts: 1 }
      this.failures = 0
      this.frames.clear()
      try {
        await this.serialize(async () => { if (current()) await applyScreenProfile(track, profile, current) })
      } catch {
        if (current()) { this.snapshot.status = 'failed'; this.terminal = true }
      }
    } catch {
      if (current() && !this.terminal) {
        this.failures = 0
        this.snapshot = { status: 'checking', reason: 'unavailable', attempts: this.snapshot?.attempts ?? 0 }
      }
    } finally { this.checking = false }
  }
}
