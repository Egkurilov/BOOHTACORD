import { rnnoiseReleaseEnabled } from '../capabilities'
import { browserProcessingConstraints, type AudioProcessingOptions, type NoiseSuppressionFallbackReason } from '../types'

import { MicrophoneAdapterPublication } from './publication'
export abstract class MicrophoneAdapterProfile extends MicrophoneAdapterPublication {
  protected async configure(options: AudioProcessingOptions, generation: number): Promise<void> {
    if (options.noiseSuppressionMode === 'rnnoise' && !rnnoiseReleaseEnabled()) { await this.fallback(options, 'release-disabled', generation); return }
    await this.track!.applyConstraints(browserProcessingConstraints(options))
    this.assertCurrent(generation)
    if (options.noiseSuppressionMode !== 'rnnoise') { this.describeCapture(options); await this.attachControls(options, generation); return }
    this.state = { requestedMode: 'rnnoise', effectiveMode: 'unknown', status: 'initializing' }
    const processor = this.dependencies.createProcessor({
      onFailure: (reason) => this.recoverProcessor(processor, reason, generation),
      onState: (state) => { if (!this.closed && generation === this.generation && this.processor === processor) this.state = { ...state, requestedMode: 'rnnoise' } },
    }, options)
    this.processor = processor
    processor.mute()
    try {
      await this.track!.setProcessor(processor)
      this.assertCurrent(generation)
      if (!processor.processedTrack || this.state.status === 'error') throw new Error('Аудиофильтр не предоставил рабочий выход.')
      if (this.state.status !== 'active') this.state = { ...this.state, requestedMode: 'rnnoise', effectiveMode: 'rnnoise', status: 'active' }
    } catch (cause) {
      this.assertCurrent(generation)
      const reason = (cause as { reason?: NoiseSuppressionFallbackReason })?.reason ?? this.state.fallbackReason ?? 'processor-error'
      await this.fallback(options, reason, generation)
    }
  }
  protected async attachControls(options: AudioProcessingOptions, generation: number): Promise<void> {
    const processor = this.dependencies.createControlsProcessor?.(options, () => this.failMuted())
    if (!processor) return
    this.processor = processor
    processor.mute()
    await this.track!.setProcessor(processor)
    this.assertCurrent(generation)
    if (!processor.processedTrack) throw new Error('Обработка микрофона не предоставила выход.')
  }
  protected describeCapture(options: AudioProcessingOptions, reason?: NoiseSuppressionFallbackReason): void {
    const reported = this.readCaptureSettings()?.noiseSuppression
    const expected = reason ? 'browser' : options.noiseSuppressionMode
    const effective = reported === undefined ? 'unknown' : reported ? 'browser' : 'off'
    this.state = { requestedMode: options.noiseSuppressionMode, effectiveMode: effective, status: reason ? 'fallback' : effective === expected ? 'active' : 'unsupported', ...(reason ? { fallbackReason: reason } : {}) }
  }
  protected async fallback(options: AudioProcessingOptions, reason: NoiseSuppressionFallbackReason, generation: number): Promise<void> {
    this.silence()
    await this.removeProcessor()
    await this.track!.applyConstraints(browserProcessingConstraints({ ...options, noiseSuppressionMode: 'browser' }))
    this.assertCurrent(generation)
    this.describeCapture(options, reason)
    await this.attachControls(options, generation)
  }
}
