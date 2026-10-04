import type { AudioProcessorOptions } from 'livekit-client'
import type { MicrophoneProcessor } from '../noise_suppression/livekit_microphone_adapter'
import url from './controls.worklet.ts?worker&url'
import { microphoneMeter, readMicrophoneControls, subscribeMicrophoneControls } from './runtime'
/** Owns derived tracks only; borrowed capture/context remain SDK-owned. */
export class MicrophoneControlsProcessor implements MicrophoneProcessor {
  readonly name = 'microphone-controls'
  sourceTrack?: MediaStreamTrack
  processedTrack?: MediaStreamTrack
  private node?: AudioWorkletNode
  private source?: MediaStreamAudioSourceNode
  private destination?: MediaStreamAudioDestinationNode
  private unsubscribe?: () => void
  private generation = 0
  private intent = 0
  private cancelUnmute?: () => void
  constructor(private agc: boolean, private inner?: MicrophoneProcessor, private onFailure?: () => void) {}
  private apply = () => this.node?.port.postMessage({ type: 'controls', ...readMicrophoneControls(), agc: this.agc })
  private async loadModule(context: AudioContext): Promise<void> {
    let timer: ReturnType<typeof setTimeout> | undefined
    try {
      await Promise.race([context.audioWorklet.addModule(url), new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('Обработка микрофона не загрузилась.')), 5000)
      })])
    } finally { if (timer !== undefined) clearTimeout(timer) }
  }
  async init(options: AudioProcessorOptions): Promise<void> {
    const generation = ++this.generation
    this.sourceTrack = options.track
    microphoneMeter.value = { levelDb: -90, clipping: false, gateOpen: false, status: 'initializing' }
    try {
      await this.inner?.init(options)
      if (generation !== this.generation) return
      await this.loadModule(options.audioContext)
      if (generation !== this.generation) return
      const node = new AudioWorkletNode(options.audioContext, 'boohtacord-microphone-controls', { numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1], channelCount: 1, channelCountMode: 'explicit' })
      this.node = node
      node.port.onmessage = ({ data }) => {
        if (generation !== this.generation) return
        if (data.type === 'meter') microphoneMeter.value = { levelDb: data.levelDb, clipping: data.clipping, gateOpen: data.gateOpen, status: 'active' }
      }
      node.onprocessorerror = () => { this.mute(); microphoneMeter.value = { ...microphoneMeter.value, status: 'error' }; this.onFailure?.() }
      this.destination = options.audioContext.createMediaStreamDestination()
      this.source = options.audioContext.createMediaStreamSource(new MediaStream([this.inner?.processedTrack ?? options.track]))
      this.source.connect(node); node.connect(this.destination)
      this.processedTrack = this.destination.stream.getAudioTracks()[0]
      this.processedTrack.enabled = false
      this.apply()
      this.unsubscribe = subscribeMicrophoneControls(this.apply)
    } catch (cause) {
      await this.destroy()
      microphoneMeter.value = { ...microphoneMeter.value, status: 'unsupported' }
      throw cause
    }
  }
  async restart(options: AudioProcessorOptions): Promise<void> { await this.destroy(); await this.init(options) }
  mute(): void {
    this.intent++
    this.cancelUnmute?.()
    this.inner?.mute()
    if (this.processedTrack) this.processedTrack.enabled = false
    this.node?.port.postMessage({ type: 'mute' })
    microphoneMeter.value = { ...microphoneMeter.value, levelDb: -90, clipping: false, gateOpen: false }
  }
  async unmute(): Promise<void> {
    const generation = this.generation
    const intent = ++this.intent
    await this.inner?.unmute()
    if (generation !== this.generation || intent !== this.intent || !this.node) throw new Error('Обработка микрофона остановлена.')
    if (this.inner?.processedTrack) this.inner.processedTrack.enabled = true
    const node = this.node
    await new Promise<void>((resolve, reject) => {
      const finish = (cause?: Error) => { clearTimeout(timer); node.port.removeEventListener('message', ack); this.cancelUnmute = undefined; cause ? reject(cause) : resolve() }
      const ack = ({ data }: MessageEvent) => { if (data.type === 'unmute' && data.intent === intent) finish() }
      const timer = setTimeout(() => finish(new Error('Микрофон не подтвердил включение.')), 1500)
      this.cancelUnmute = () => finish(new Error('Микрофон выключен.'))
      node.port.addEventListener('message', ack); node.port.postMessage({ type: 'unmute', intent })
    })
    if (generation !== this.generation || intent !== this.intent) throw new Error('Обработка микрофона остановлена.')
    // Adapter enables the final output after checking the latest mute intent.
  }
  async destroy(): Promise<void> {
    this.generation++; this.mute(); this.unsubscribe?.(); this.unsubscribe = undefined
    if (this.node) { this.node.port.onmessage = null; this.node.onprocessorerror = null; this.node.port.close() }
    this.node?.disconnect(); this.source?.disconnect(); this.destination?.disconnect(); this.processedTrack?.stop()
    this.node = undefined; this.source = undefined; this.destination = undefined; this.processedTrack = undefined; this.sourceTrack = undefined
    await this.inner?.destroy()
    microphoneMeter.value = { levelDb: -90, clipping: false, gateOpen: false, status: 'idle' }
  }
}
