import { beginScreenPreview, invalidateScreenPreview, uploadScreenPreview, type ScreenPreviewRequest } from './screen_preview_client'
import { validScreenThumbnail } from './screen_thumbnail'

export class LatestScreenPreviewUploader {
  private leaseId = ''
  private generationId = ''
  private revision = 0
  private pending: Uint8Array | null = null
  private pumping: Promise<void> | null = null
  private beginning: Promise<void> | null = null
  private epoch = 0

  constructor(private readonly request: ScreenPreviewRequest = fetch) {}

  async start(leaseId: string): Promise<void> {
    if (this.leaseId === leaseId && this.generationId) return
    if (this.leaseId === leaseId && this.beginning) return this.beginning
    const epoch = ++this.epoch
    const previous = this.generationId ? { leaseId: this.leaseId, generationId: this.generationId } : null
    this.leaseId = leaseId
    this.generationId = ''
    this.revision = 0
    this.pending = null
    const operation = (async () => {
      if (previous) await invalidateScreenPreview(previous.leaseId, previous.generationId, this.request).catch(() => undefined)
      const generationId = await beginScreenPreview(leaseId, this.request)
      if (epoch !== this.epoch) {
        await invalidateScreenPreview(leaseId, generationId, this.request).catch(() => undefined)
        return
      }
      this.generationId = generationId
      this.drain()
    })()
    this.beginning = operation
    try { await operation } finally { if (epoch === this.epoch) this.beginning = null }
  }

  offer(bytes: Uint8Array): void {
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

  async stop(): Promise<void> {
    ++this.epoch
    this.pending = null
    const leaseId = this.leaseId, generationId = this.generationId
    const beginning = this.beginning
    this.leaseId = ''
    this.generationId = ''
    await this.pumping?.catch(() => undefined)
    await beginning?.catch(() => undefined)
    if (leaseId && generationId) await invalidateScreenPreview(leaseId, generationId, this.request).catch(() => undefined)
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
      try { await uploadScreenPreview(leaseId, generationId, ++this.revision, bytes, this.request) }
      catch { /* The next capture is the bounded latest-state retry. */ }
    }
  }
}
