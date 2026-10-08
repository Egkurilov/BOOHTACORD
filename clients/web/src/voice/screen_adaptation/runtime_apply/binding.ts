import type { ScreenDiagnostics } from '../../screen_diagnostics'
import type { ScreenPublisherAdapter } from '../../screen_publisher/adapter'
import type { ScreenProfile } from '../../screen_profile/policy'
import { ScreenAdaptationRuntime } from './runtime'
import type { AdaptationRuntimeOptions } from './types'

export class ScreenAdaptationBinding<T> {
  readonly runtime: ScreenAdaptationRuntime<T>
  readonly options: AdaptationRuntimeOptions
  constructor(writer: ScreenPublisherAdapter<T>, options: AdaptationRuntimeOptions = {},
    private readonly onApplied?: (profile: ScreenProfile) => Promise<void>) {
    this.runtime = new ScreenAdaptationRuntime(writer, options)
    this.options = this.runtime.options
  }
  reset(): void { this.runtime.reset() }
  async read(readDiagnostics: () => Promise<ScreenDiagnostics>): Promise<ScreenDiagnostics> {
    const ticket = this.runtime.capture()
    const diagnostics = await readDiagnostics()
    if (!this.runtime.enabled || !this.options.readWindow) return diagnostics
    if (!ticket || !this.runtime.current(ticket)) return { ...diagnostics, adaptationReason: 'stale-owner' }
    const state = this.runtime.state!
    let window
    try {
      window = await this.options.readWindow(diagnostics, { publicationGeneration: ticket.generation,
        currentProfile: state.currentProfile, userCeiling: state.ceilingProfile })
    } catch { return { ...diagnostics, adaptationReason: 'input-unavailable' } }
    if (!this.runtime.current(ticket)) return { ...diagnostics, adaptationReason: 'stale-owner' }
    if (!window) return { ...diagnostics, adaptationReason: 'unknown-bottleneck' }
    const result = await this.runtime.step(window, (this.options.now ?? performance.now.bind(performance))(), ticket)
    if (result.applied && result.revision === this.runtime.writer.currentRevision && !this.runtime.writer.busy) {
      await this.onApplied?.(this.runtime.writer.active!.profile)
    }
    return { ...diagnostics, adaptationReason: result.reason }
  }
}
