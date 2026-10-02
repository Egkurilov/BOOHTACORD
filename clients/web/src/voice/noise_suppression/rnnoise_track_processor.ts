import type { AudioProcessorOptions, TrackProcessor, Track } from 'livekit-client'
import workletUrl from './rnnoise.worklet.ts?worker&url'
import { supportsRnnoise, supportedContextRate } from './capabilities'
import { loadRnnoiseAssets, type RnnoiseAssets } from './rnnoise_loader'
import { readRnnoiseCounters, type RnnoiseCounters } from './diagnostics'
import type { NoiseSuppressionFallbackReason, NoiseSuppressionRuntimeState } from './types'
interface RnnoiseProcessorOptions {
  onFailure?: (reason: NoiseSuppressionFallbackReason) => void
  onState?: (state: NoiseSuppressionRuntimeState & Partial<RnnoiseCounters>) => void
  loadAssets?: () => Promise<RnnoiseAssets>
  workletUrl?: string
  initTimeoutMs?: number
}
/** Owns derived nodes/track only; LiveKit owns source capture and AudioContext. */
export class RnnoiseTrackProcessor implements TrackProcessor<Track.Kind.Audio, AudioProcessorOptions> {
  readonly name = 'rnnoise'
  processedTrack?: MediaStreamTrack
  sourceTrack?: MediaStreamTrack
  runtimeState: NoiseSuppressionRuntimeState & Partial<RnnoiseCounters> = {
    requestedMode: 'rnnoise', effectiveMode: 'unknown', status: 'idle',
  }
  private source?: MediaStreamAudioSourceNode
  private destination?: MediaStreamAudioDestinationNode
  private worklet?: AudioWorkletNode
  private generation = 0
  private muted = true
  private acknowledgeUnmute?: () => void
  private cancelUnmute?: () => void
  private failed = false
  private cancelInit?: () => void
  constructor(private readonly options: RnnoiseProcessorOptions = {}) {}
  private update(state: Partial<NoiseSuppressionRuntimeState & RnnoiseCounters>): void {
    this.runtimeState = { ...this.runtimeState, ...state }
    this.options.onState?.(this.runtimeState)
  }
  private fail(reason: NoiseSuppressionFallbackReason): void {
    if (this.failed) return
    this.failed = true
    // Derived track closes transmission immediately, before asynchronous fallback.
    if (this.processedTrack) this.processedTrack.enabled = false
    this.worklet?.port.postMessage({ type: 'mute' })
    this.update({ status: 'error', effectiveMode: 'unknown', fallbackReason: reason })
    this.options.onFailure?.(reason)
  }
  private async bounded<T>(operation: Promise<T>): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined
    try {
      return await Promise.race([operation, new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('RNNoise preparation timeout')), this.options.initTimeoutMs ?? 8000)
      })])
    } finally { if (timer !== undefined) clearTimeout(timer) }
  }
  async init(opts: AudioProcessorOptions): Promise<void> {
    const initStarted = performance.now()
    const generation = ++this.generation
    this.failed = false
    this.muted = true
    this.sourceTrack = opts.track
    let captureSampleRate: number | undefined
    try {
      const reported = opts.track.getSettings?.().sampleRate
      if (reported !== undefined && Number.isSafeInteger(reported) && reported > 0 && reported <= 384000) captureSampleRate = reported
    } catch { /* Missing browser diagnostics never prevent processing. */ }
    this.update({ status: 'initializing', effectiveMode: 'unknown', fallbackReason: undefined, captureSampleRate, initDurationMs: undefined })
    let reason: NoiseSuppressionFallbackReason = 'unsupported'
    try {
      if (!supportsRnnoise()) throw new Error('RNNoise unsupported')
      reason = 'sample-rate'
      this.update({ contextSampleRate: opts.audioContext.sampleRate })
      if (!supportedContextRate(opts.audioContext)) throw new Error('RNNoise requires 48 kHz context')
      reason = 'asset-load'
      const assets = await this.bounded((this.options.loadAssets ?? loadRnnoiseAssets)())
      if (generation !== this.generation) return
      reason = 'init-timeout'
      await this.bounded(opts.audioContext.audioWorklet.addModule(this.options.workletUrl ?? workletUrl))
      if (generation !== this.generation) return
      reason = 'processor-error'
      const node = new AudioWorkletNode(opts.audioContext, 'boohtacord-rnnoise', {
        numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1], channelCount: 1,
        channelCountMode: 'explicit', processorOptions: { module: assets.module },
      })
      this.worklet = node
      node.onprocessorerror = () => this.fail('processor-error')
      reason = 'init-timeout'
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('RNNoise initialization timeout')), this.options.initTimeoutMs ?? 8000)
        this.cancelInit = () => { clearTimeout(timer); resolve() }
        node.port.onmessage = event => {
          if (generation !== this.generation) return
          if (event.data.type === 'unmuted') this.acknowledgeUnmute?.()
          if (event.data.type === 'ready') { clearTimeout(timer); this.cancelInit = undefined; resolve() }
          if (event.data.type === 'health') {
            const counters = readRnnoiseCounters(event.data)
            if (!counters) { this.fail('processor-error'); return }
            this.update(counters)
            if (counters.processorErrors) this.fail('processor-error')
            else if (counters.fifoOverruns || counters.fifoUnderruns > 48000) this.fail('overload')
          }
        }
      })
      if (generation !== this.generation) return
      reason = 'processor-error'
      this.source = opts.audioContext.createMediaStreamSource(new MediaStream([opts.track]))
      this.destination = opts.audioContext.createMediaStreamDestination()
      this.processedTrack = this.destination.stream.getAudioTracks()[0]
      this.processedTrack.enabled = !this.muted
      node.port.postMessage({ type: this.muted ? 'mute' : 'unmute' })
      this.source.connect(node); node.connect(this.destination)
      this.update({ status: 'active', effectiveMode: 'rnnoise', modelId: assets.modelId })
    } catch (error) {
      if (generation === this.generation) {
        this.fail(reason)
        this.releaseGraph()
        throw error
      }
    } finally {
      if (generation === this.generation) {
        const duration = performance.now() - initStarted
        // Background suspension or invalid clocks must not become a numeric claim.
        this.update({ initDurationMs: Number.isFinite(duration) && duration >= 0 && duration <= 60000 ? duration : undefined })
      }
    }
  }
  async restart(opts: AudioProcessorOptions): Promise<void> {
    await this.destroy()
    await this.init(opts)
  }
  mute(): void {
    this.muted = true
    if (this.processedTrack) this.processedTrack.enabled = false
    this.worklet?.port.postMessage({ type: 'mute' })
  }
  async unmute(): Promise<void> {
    if (!this.worklet || this.failed) return
    const generation = this.generation
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => { this.acknowledgeUnmute = undefined; this.cancelUnmute = undefined; reject(new Error('RNNoise reset timeout')) }, 1000)
      const finish = () => { clearTimeout(timer); this.acknowledgeUnmute = undefined; this.cancelUnmute = undefined; resolve() }
      this.acknowledgeUnmute = finish; this.cancelUnmute = finish
      this.worklet!.port.postMessage({ type: 'unmute' })
    })
    if (generation !== this.generation || this.failed) return
    this.muted = false
    // Adapter enables the derived track only after checking current mute intent.
  }
  private releaseGraph(): void {
    this.cancelUnmute?.(); this.cancelUnmute = undefined
    this.source?.disconnect(); this.worklet?.disconnect(); this.destination?.disconnect()
    if (this.worklet) {
      this.worklet.onprocessorerror = null
      this.worklet.port.onmessage = null
      this.worklet.port.postMessage({ type: 'destroy' }); this.worklet.port.close()
    }
    this.processedTrack?.stop()
    this.source = undefined; this.worklet = undefined; this.destination = undefined
    this.processedTrack = undefined; this.sourceTrack = undefined
  }
  async destroy(): Promise<void> {
    this.generation++
    this.cancelInit?.(); this.cancelInit = undefined
    this.releaseGraph()
    this.update({ status: 'idle', effectiveMode: 'unknown' })
  }
}
