/** Fixed storage; push/shift never allocate and never grow. */
export class SampleRingBuffer {
  private readonly samples: Float32Array
  private read = 0
  private write = 0
  size = 0
  constructor(readonly capacity: number) {
    if (!Number.isInteger(capacity) || capacity <= 0) throw new Error('Invalid FIFO capacity')
    this.samples = new Float32Array(capacity)
  }
  push(sample: number): boolean {
    if (this.size === this.capacity) return false
    this.samples[this.write] = sample
    this.write = (this.write + 1) % this.capacity
    this.size++
    return true
  }
  shift(): number | undefined {
    if (!this.size) return undefined
    const sample = this.samples[this.read]
    this.samples[this.read] = 0
    this.read = (this.read + 1) % this.capacity
    this.size--
    return sample
  }
  clear(): void {
    this.samples.fill(0)
    this.read = this.write = this.size = 0
  }
}
export function toPcm16Float(sample: number): number {
  return Number.isFinite(sample) ? Math.max(-1, Math.min(1, sample)) * 32768 : 0
}
export function fromPcm16Float(sample: number): number {
  return Number.isFinite(sample) ? Math.max(-1, Math.min(1, sample / 32768)) : 0
}
