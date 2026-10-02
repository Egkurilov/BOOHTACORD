import { UpdateCheckError } from './client'

const retrySeconds = [30, 60, 120, 300]

export class UpdateScheduler {
  private timer: ReturnType<typeof setTimeout> | null = null
  private running = false
  private disposed = false
  private failures = 0
  private lastAttempt = 0
  private serverDelay = 0

  constructor(private readonly check: () => Promise<void>, private readonly random = Math.random) {}

  start(): void {
    if (this.disposed || this.timer !== null || this.running) return
    this.schedule(this.random() * 5_000)
    if (typeof document !== 'undefined') document.addEventListener('visibilitychange', this.visibility)
    if (typeof window !== 'undefined') { window.addEventListener('online', this.resume); window.addEventListener('pageshow', this.resume) }
  }

  manual(): void { if (!this.running && !this.disposed) void this.run() }

  private readonly visibility = (): void => {
    if (document.visibilityState !== 'visible') return
    if (Date.now() - this.lastAttempt > 60_000) this.manual()
    else if (this.timer === null && !this.running) this.schedule(60_000 - (Date.now() - this.lastAttempt))
  }

  private readonly resume = (): void => this.visibility()

  private schedule(delay: number): void {
    if (this.disposed || (typeof document !== 'undefined' && document.visibilityState === 'hidden')) return
    this.timer = globalThis.setTimeout(() => { this.timer = null; void this.run() }, delay)
  }

  private async run(): Promise<void> {
    if (this.running || this.disposed) return
    this.running = true; this.lastAttempt = Date.now()
    try { await this.check(); this.failures = 0 }
    catch (cause) {
      this.failures = Math.min(this.failures + 1, retrySeconds.length)
      this.serverDelay = cause instanceof UpdateCheckError ? cause.retryAfterMs ?? 0 : 0
    }
    finally {
      this.running = false
      if (!this.disposed) {
        const base = this.failures ? retrySeconds[this.failures - 1] * 1_000 : 300_000
        this.schedule(Math.max(this.serverDelay, base * (0.9 + this.random() * 0.2)))
      }
    }
  }

  dispose(): void {
    this.disposed = true
    if (this.timer !== null) globalThis.clearTimeout(this.timer)
    this.timer = null
    if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', this.visibility)
    if (typeof window !== 'undefined') { window.removeEventListener('online', this.resume); window.removeEventListener('pageshow', this.resume) }
  }
}
