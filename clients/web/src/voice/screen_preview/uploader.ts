import { beginScreenPreview, invalidateScreenPreview, uploadScreenPreview, type ScreenPreviewRequest } from './client'
import { validScreenThumbnail } from '../screen_thumbnail'
import { ScreenPreviewRequestScopes } from './request_scopes'
import { screenMediaRollout } from '../screen_rollout/policy'

const shutdownGraceMs = 250
async function settlesWithin(operation: Promise<unknown>): Promise<boolean> {
  let timer!: ReturnType<typeof setTimeout>
  const settled = operation.then(() => true, () => true)
  return Promise.race([settled, new Promise<boolean>((resolve) => { timer = setTimeout(() => resolve(false), shutdownGraceMs) })])
    .finally(() => clearTimeout(timer))
}

export class LatestScreenPreviewUploader {
  private leaseId = ''
  private generationId = ''
  private revision = 0
  private pending: Uint8Array | null = null
  private pumping: Promise<void> | null = null
  private beginning: Promise<void> | null = null
  private stopping: Promise<void> | null = null
  private epoch = 0
  private requestScopes: ScreenPreviewRequestScopes

  constructor(request: ScreenPreviewRequest = fetch, private readonly enabled = screenMediaRollout().jpegPreview) { this.requestScopes = new ScreenPreviewRequestScopes(request) }

  private async invalidateBounded(leaseId: string, generationId: string): Promise<void> {
    const scope = this.requestScopes.create()
    const operation = invalidateScreenPreview(leaseId, generationId, scope.request).catch(() => undefined).finally(scope.release)
    if (!await settlesWithin(operation)) { scope.abort(); scope.release() }
  }

  async start(leaseId: string): Promise<void> {
    if (!this.enabled) return
    if (this.leaseId === leaseId && this.generationId) return
    if (this.leaseId === leaseId && this.beginning) return this.beginning
    const epoch = ++this.epoch
    const previous = this.generationId ? { leaseId: this.leaseId, generationId: this.generationId } : null
    this.leaseId = leaseId
    this.generationId = ''
    this.revision = 0
    this.pending = null
    const operation = (async () => {
      if (previous) await this.invalidateBounded(previous.leaseId, previous.generationId)
      if (epoch !== this.epoch) return
      const scope = this.requestScopes.create()
      let generationId: string
      try { generationId = await beginScreenPreview(leaseId, scope.request) } finally { scope.release() }
      if (epoch !== this.epoch) {
        await this.invalidateBounded(leaseId, generationId)
        return
      }
      this.generationId = generationId
      this.drain()
    })()
    this.beginning = operation
    try { await operation } finally { if (this.beginning === operation) this.beginning = null }
  }

  offer(bytes: Uint8Array): void {
    if (!this.enabled) return
    if (!validScreenThumbnail(bytes)) return
    if (!this.generationId) {
      if (!this.leaseId) return
      const starting = this.start(this.leaseId)
      this.pending = bytes.slice()
      void starting.catch(() => undefined)
      return
    }
    this.pending = bytes.slice()
    this.drain()
  }

  stop(): Promise<void> {
    if (this.stopping) return this.stopping
    let shared!: Promise<void>
    shared = this.stopCurrent().finally(() => {
      if (this.stopping === shared) this.stopping = null
    })
    this.stopping = shared
    return shared
  }

  private async stopCurrent(): Promise<void> {
    ++this.epoch
    this.pending = null
    const leaseId = this.leaseId, generationId = this.generationId
    const beginning = this.beginning
    this.leaseId = ''
    this.generationId = ''
    this.requestScopes.abortAll()
    const pending = Promise.all([this.pumping?.catch(() => undefined), beginning?.catch(() => undefined)])
    await settlesWithin(pending)
    if (leaseId && generationId) await this.invalidateBounded(leaseId, generationId)
  }

  private drain(): void {
    if (this.pumping || !this.generationId || !this.pending) return
    this.pumping = this.pump().finally(() => {
      this.pumping = null
      this.drain()
    })
  }

  private async pump(): Promise<void> {
    while (this.pending && this.generationId) {
      const bytes = this.pending, leaseId = this.leaseId, generationId = this.generationId
      this.pending = null
      const scope = this.requestScopes.create()
      try { await uploadScreenPreview(leaseId, generationId, ++this.revision, bytes, scope.request) }
      catch { /* The next capture is the bounded latest-state retry. */ }
      finally { scope.release() }
    }
  }
}
