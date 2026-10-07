import { readScreenPreview, ScreenPreviewMissing, type ScreenPreviewFrame, type ScreenPreviewHint } from './screen_preview_client'
import type { ScreenPreviewRequest } from './screen_preview_client'

interface State { hint: ScreenPreviewHint; revision: number; pending: number; running: boolean; poll: boolean; timer?: ReturnType<typeof setTimeout> }
export interface ScreenPreviewSink { apply(hint: ScreenPreviewHint, bytes: Uint8Array): void; clear(leaseId: string): void }

export class LatestScreenPreviewReader {
  private readonly states = new Map<string, State>()
  constructor(private readonly sink: ScreenPreviewSink, private readonly request: ScreenPreviewRequest = fetch, private readonly read = readScreenPreview) {}

  accept(hint: ScreenPreviewHint): void {
    let state = this.states.get(hint.leaseId)
    if (state?.hint.generationId !== hint.generationId) {
      this.sink.clear(hint.leaseId)
      state?.timer && clearTimeout(state.timer)
      this.states.delete(hint.leaseId)
      state = undefined
    }
    if (!state) {
      if (this.states.size >= 16) { const oldest = this.states.keys().next().value; if (oldest) { const prior = this.states.get(oldest); if (prior?.timer) clearTimeout(prior.timer); this.states.delete(oldest); this.sink.clear(oldest) } }
      state = { hint, revision: 0, pending: 0, running: false, poll: false }
      this.states.set(hint.leaseId, state)
    }
    state.hint = hint
    state.pending = Math.max(state.pending, hint.revision)
    if (!state.running) void this.pump(hint.leaseId, state)
  }

  invalidate(leaseId: string, generationId: string): void {
    const state = this.states.get(leaseId)
    if (!state || state.hint.generationId !== generationId) return
    if (state.timer) clearTimeout(state.timer)
    this.states.delete(leaseId)
    this.sink.clear(leaseId)
  }

  clear(): void { this.states.forEach((state, leaseId) => { if (state.timer) clearTimeout(state.timer); this.sink.clear(leaseId) }); this.states.clear() }

  private async pump(leaseId: string, state: State): Promise<void> {
    state.running = true
    try {
      while (this.states.get(leaseId) === state && (state.pending > state.revision || state.poll)) {
        const hint = state.hint, target = state.pending
        state.pending = state.revision
        state.poll = false
        let frame: ScreenPreviewFrame | null = null
        try { frame = await this.read(hint, state.revision, this.request) }
        catch (cause) {
          if (cause instanceof ScreenPreviewMissing && this.states.get(leaseId) === state) { this.invalidate(leaseId, hint.generationId); return }
        }
        if (this.states.get(leaseId) !== state || state.hint.generationId !== hint.generationId) return
        if (frame && frame.revision > state.revision) {
          state.revision = frame.revision
          if (state.pending <= frame.revision) this.sink.apply(hint, frame.bytes)
        } else state.revision = Math.max(state.revision, target)
      }
    } finally {
      state.running = false
      if (this.states.get(leaseId) === state) state.timer = setTimeout(() => {
        if (this.states.get(leaseId) !== state) return
        state.poll = true
        void this.pump(leaseId, state)
      }, 5_000)
    }
  }
}
