import { MicrophoneDsp } from './dsp'
declare const sampleRate: number
declare const AudioWorkletProcessor: { new(): { port: MessagePort } }
declare function registerProcessor(name: string, processor: unknown): void
class ControlsWorklet extends AudioWorkletProcessor {
  private dsp = new MicrophoneDsp(sampleRate)
  private muted = true
  private elapsed = 0
  private clipped = false
  private clippingHold = 0
  constructor() {
    super()
    this.port.onmessage = ({ data }) => {
      if (data.type === 'controls') this.dsp.configure(data.settings, data.vad, data.agc)
      if (data.type === 'mute' || data.type === 'unmute') {
        this.dsp.reset(); this.muted = data.type === 'mute'
        this.elapsed = 0; this.clipped = false; this.clippingHold = 0
        this.port.postMessage({ type: data.type, intent: data.intent })
      }
    }
  }
  process(inputs: Float32Array[][], outputs: Float32Array[][]): boolean {
    const output = outputs[0]?.[0]
    const input = inputs[0]?.[0]
    if (!output) return true
    if (this.muted || !input) { output.fill(0); return true }
    this.dsp.process(input, output)
    this.clippingHold = this.dsp.clipping ? sampleRate / 4 : Math.max(0, this.clippingHold - output.length)
    this.clipped ||= this.clippingHold > 0
    this.elapsed += output.length
    if (this.elapsed >= sampleRate / 10) {
      this.port.postMessage({ type: 'meter', levelDb: this.dsp.levelDb, gateOpen: this.dsp.gateOpen, clipping: this.clipped })
      this.elapsed = 0; this.clipped = false
    }
    return true
  }
}
registerProcessor('boohtacord-microphone-controls', ControlsWorklet)
