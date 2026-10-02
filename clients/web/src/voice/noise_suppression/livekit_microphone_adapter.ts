import { rnnoiseReleaseEnabled } from './capabilities'
import type { AudioProcessorOptions, LocalAudioTrack, Track, TrackProcessor } from 'livekit-client'
import { microphoneConstraints, microphonePublishOptions, defaultAudioProcessing, type MicrophonePublishOptions } from '../media_publishing'
import type { BrowserAudioProcessingSettings } from '../audio_processing_diagnostics'
import { browserProcessingConstraints, normalizeAudioProcessing, type AudioProcessingOptions, type NoiseSuppressionFallbackReason, type NoiseSuppressionRuntimeState } from './types'

export interface MicrophoneProcessor extends TrackProcessor<Track.Kind.Audio, AudioProcessorOptions> {
  mute(): void
  unmute(): void | Promise<void>
  readonly sourceTrack?: MediaStreamTrack
}
export interface MicrophoneAdapterDependencies {
  createTrack(options: MediaTrackConstraints): Promise<LocalAudioTrack>
  publishTrack(track: LocalAudioTrack, options: MicrophonePublishOptions): Promise<unknown>
  unpublishTrack(track: LocalAudioTrack): Promise<unknown>
  createProcessor(callbacks: { onFailure(reason: NoiseSuppressionFallbackReason): void; onState(state: NoiseSuppressionRuntimeState): void }): MicrophoneProcessor
}
/** Sole owner of local microphone capture, publication and processor transitions. */
export class LiveKitMicrophoneAdapter {
  private queue: Promise<unknown> = Promise.resolve()
  private generation = 0
  private closed = false
  private desiredEnabled = false
  private track?: LocalAudioTrack
  private source?: MediaStreamTrack
  private processor?: MicrophoneProcessor
  private published = false
  private options: AudioProcessingOptions = { ...defaultAudioProcessing }
  private deviceId?: string
  private readonly listeners = new Set<(state: NoiseSuppressionRuntimeState) => void>()
  private stateValue: NoiseSuppressionRuntimeState = { requestedMode: 'browser', effectiveMode: 'unknown', status: 'idle' }
  constructor(private readonly dependencies: MicrophoneAdapterDependencies) {}
  private get state(): NoiseSuppressionRuntimeState { return this.stateValue }
  private set state(value: NoiseSuppressionRuntimeState) { this.stateValue = value; for (const listener of this.listeners) listener({ ...value }) }
  subscribe(listener: (state: NoiseSuppressionRuntimeState) => void): () => void {
    if (this.closed) return () => undefined
    this.listeners.add(listener)
    listener(this.runtimeState)
    return () => this.listeners.delete(listener)
  }
  get runtimeState(): NoiseSuppressionRuntimeState { return { ...this.state } }
  readCaptureSettings(): BrowserAudioProcessingSettings | undefined { return (this.processor?.sourceTrack ?? this.source)?.getSettings() }
  readOutputTrack(): MediaStreamTrack | undefined { return this.track?.mediaStreamTrack }

  setEnabled(enabled: boolean, options: AudioProcessingOptions): Promise<void> {
    if (this.closed) return Promise.reject(new Error('Голосовое подключение закрыто.'))
    this.desiredEnabled = enabled
    if (!enabled) this.silence()
    return this.enqueue(async (generation) => {
      if (!this.track && !this.desiredEnabled) { this.options = normalizeAudioProcessing(options); this.state = { requestedMode: this.options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'idle' }; return }
      if (!this.track) await this.create(normalizeAudioProcessing(options), generation)
      else if (JSON.stringify(this.options) !== JSON.stringify(options)) await this.changeProfile(normalizeAudioProcessing(options), generation)
      await this.restoreIntent(generation)
    })
  }
  setProcessing(options: AudioProcessingOptions): Promise<void> {
    return this.enqueue(async (generation) => {
      const next = normalizeAudioProcessing(options)
      if (!this.track) { this.options = next; this.state = { requestedMode: next.noiseSuppressionMode, effectiveMode: 'unknown', status: 'idle' }; return }
      await this.changeProfile(next, generation)
    })
  }
  switchDevice(deviceId: string): Promise<boolean> {
    return this.enqueue(async (generation) => {
      const previous = this.deviceId
      this.deviceId = deviceId
      if (!this.track) return true
      await this.track.mute()
      this.silence()
      try {
        await this.removeProcessor()
        await this.track.restartTrack({ ...microphoneConstraints(this.options), deviceId: { exact: deviceId } })
        this.source = this.track.mediaStreamTrack
        this.silence()
        this.assertCurrent(generation)
        await this.configure(this.options, generation)
        await this.restoreIntent(generation)
        return true
      } catch (cause) {
        this.deviceId = previous
        try {
          await this.removeProcessor()
          await this.track.restartTrack({ ...microphoneConstraints(this.options), ...(previous ? { deviceId: { exact: previous } } : {}) })
          this.source = this.track.mediaStreamTrack
          this.silence()
          await this.configure(this.options, generation)
          await this.restoreIntent(generation)
        } catch { this.failMuted() }
        throw cause
      }
    })
  }
  dispose(): Promise<void> {
    if (this.closed) return this.queue.then(() => undefined)
    // Revoke before waiting for a pending create/init/recovery to settle.
    this.closed = true
    this.listeners.clear()
    this.generation++
    this.desiredEnabled = false
    this.silence()
    const cleanup = this.queue.catch(() => undefined).then(() => this.cleanup())
    this.queue = cleanup
    return cleanup
  }
  private enqueue<T>(operation: (generation: number) => Promise<T>): Promise<T> {
    if (this.closed) return Promise.reject(new Error('Голосовое подключение закрыто.'))
    const generation = this.generation
    const result = this.queue.catch(() => undefined).then(async () => { this.assertCurrent(generation); return operation(generation) })
    this.queue = result
    return result
  }
  private assertCurrent(generation: number): void {
    if (this.closed || generation !== this.generation) throw new Error('Голосовое подключение закрыто.')
  }
  private silence(): void {
    this.processor?.mute()
    const source = this.processor?.sourceTrack ?? this.source
    if (source) source.enabled = false
    if (this.track) this.track.mediaStreamTrack.enabled = false
  }
  private async create(options: AudioProcessingOptions, generation: number): Promise<void> {
    try {
      this.track = await this.dependencies.createTrack({ ...microphoneConstraints(options), ...(this.deviceId ? { deviceId: { exact: this.deviceId } } : {}) })
      this.source = this.track.mediaStreamTrack
      this.silence()
      this.assertCurrent(generation)
      await this.track.mute()
      await this.configure(options, generation)
      this.assertCurrent(generation)
      // All publication starts muted. Only restoreIntent can begin transmission.
      this.silence()
      await this.dependencies.publishTrack(this.track, microphonePublishOptions)
      this.published = true
      this.assertCurrent(generation)
      this.options = options
    } catch (cause) {
      await this.cleanup()
      this.state = { requestedMode: options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'error' }
      throw cause
    }
  }
  private async changeProfile(next: AudioProcessingOptions, generation: number): Promise<void> {
    const previous = this.options
    const previousState = this.state
    await this.track!.mute()
    this.silence()
    try {
      await this.removeProcessor()
      await this.configure(next, generation)
      this.assertCurrent(generation)
      this.options = next
      await this.restoreIntent(generation)
    } catch (cause) {
      if (!this.closed) {
        try { await this.removeProcessor(); await this.configure(previous, generation); this.state = previousState; await this.restoreIntent(generation) }
        catch { this.failMuted() }
      }
      throw cause
    }
  }
  private async configure(options: AudioProcessingOptions, generation: number): Promise<void> {
    if (options.noiseSuppressionMode === 'rnnoise' && !rnnoiseReleaseEnabled()) { await this.fallback(options, 'release-disabled', generation); return }
    await this.track!.applyConstraints(browserProcessingConstraints(options))
    this.assertCurrent(generation)
    if (options.noiseSuppressionMode !== 'rnnoise') { this.describeCapture(options); return }
    this.state = { requestedMode: 'rnnoise', effectiveMode: 'unknown', status: 'initializing' }
    const processor = this.dependencies.createProcessor({
      onFailure: (reason) => this.recoverProcessor(processor, reason, generation),
      onState: (state) => { if (!this.closed && generation === this.generation && this.processor === processor) this.state = { ...state, requestedMode: 'rnnoise' } },
    })
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
  private describeCapture(options: AudioProcessingOptions, reason?: NoiseSuppressionFallbackReason): void {
    const reported = this.readCaptureSettings()?.noiseSuppression
    const expected = reason ? 'browser' : options.noiseSuppressionMode
    const effective = reported === undefined ? 'unknown' : reported ? 'browser' : 'off'
    this.state = { requestedMode: options.noiseSuppressionMode, effectiveMode: effective, status: reason ? 'fallback' : effective === expected ? 'active' : 'unsupported', ...(reason ? { fallbackReason: reason } : {}) }
  }
  private async fallback(options: AudioProcessingOptions, reason: NoiseSuppressionFallbackReason, generation: number): Promise<void> {
    this.silence()
    await this.removeProcessor()
    await this.track!.applyConstraints(browserProcessingConstraints({ ...options, noiseSuppressionMode: 'browser' }))
    this.assertCurrent(generation)
    this.describeCapture(options, reason)
  }
  private recoverProcessor(processor: MicrophoneProcessor, reason: NoiseSuppressionFallbackReason, generation: number): void {
    if (this.closed || generation !== this.generation || this.processor !== processor) return
    this.silence()
    void this.enqueue(async (current) => {
      if (this.processor !== processor) return
      try { await this.track!.mute(); await this.fallback(this.options, reason, current); await this.restoreIntent(current) }
      catch { this.failMuted(reason) }
    }).catch(() => undefined)
  }
  private async restoreIntent(generation: number): Promise<void> {
    this.assertCurrent(generation)
    if (!this.track) return
    if (this.desiredEnabled && this.state.status !== 'error') {
      await this.track.unmute()
      if (this.closed || !this.desiredEnabled) this.silence()
      this.assertCurrent(generation)
      // Intent can change while SDK unmute awaits.
      if (!this.desiredEnabled) { this.silence(); await this.track.mute() }
      else {
        await this.processor?.unmute()
        this.assertCurrent(generation)
        if (this.desiredEnabled) this.track.mediaStreamTrack.enabled = true
        else { this.silence(); await this.track.mute() }
      }
    } else { this.silence(); await this.track.mute() }
  }
  private failMuted(reason?: NoiseSuppressionFallbackReason): void {
    this.silence()
    this.state = { requestedMode: this.options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'error', ...(reason ? { fallbackReason: reason } : {}) }
  }
  private async removeProcessor(): Promise<void> {
    const processor = this.processor
    this.processor = undefined
    if (!processor) return
    processor.mute()
    try { await this.track?.stopProcessor() } finally { await processor.destroy() }
  }
  private async cleanup(): Promise<void> {
    const track = this.track
    this.silence()
    try { await this.removeProcessor() } finally {
      if (track) {
        try { if (this.published) await this.dependencies.unpublishTrack(track) }
        finally { track.stop() }
      }
      this.track = undefined; this.source = undefined; this.published = false
    }
  }
}
