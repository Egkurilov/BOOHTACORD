interface PacketLossSample {
  timestamp: number
  packetsReceived?: number
  packetsSent?: number
  packetsLost?: number
}

const windowMs = 10_000
const minimumWindowMs = 9_000
const maximumWindowMs = 12_000

function valid(value: number | undefined): value is number {
  return value !== undefined && Number.isFinite(value) && value >= 0
}

export class ScreenPacketLossWindow {
  private samples: PacketLossSample[] = []
  durationMs: number | null = null

  clear(): void { this.samples = []; this.durationMs = null }

  add(sample: PacketLossSample): number | null {
    this.durationMs = null
    const sent = sample.packetsSent !== undefined
    const received = sent ? sample.packetsSent : sample.packetsReceived
    const lost = sample.packetsLost
    if (!Number.isFinite(sample.timestamp) || !valid(received) || !valid(lost)) {
      this.clear()
      return null
    }
    const last = this.samples.at(-1)
    if (last && (sample.timestamp <= last.timestamp || sent !== (last.packetsSent !== undefined) || received < (sent ? last.packetsSent! : last.packetsReceived!) || lost < last.packetsLost!)) this.clear()
    this.samples.push(sample)
    const cutoff = sample.timestamp - windowMs
    while (this.samples.length > 1 && this.samples[1]!.timestamp <= cutoff) this.samples.shift()
    while (this.samples.length > 1 && sample.timestamp - this.samples[0]!.timestamp > maximumWindowMs) this.samples.shift()
    const baseline = this.samples[0]!
    const elapsedMs = sample.timestamp - baseline.timestamp
    if (elapsedMs > maximumWindowMs) { this.samples = [sample]; return null }
    if (elapsedMs < minimumWindowMs) return null
    const receivedDelta = received - (sent ? baseline.packetsSent! : baseline.packetsReceived!)
    const lostDelta = lost - baseline.packetsLost!
    const total = sent ? receivedDelta : receivedDelta + lostDelta
    if (total <= 0 || lostDelta > total) return null
    this.durationMs = elapsedMs
    return Math.round((lostDelta / total) * 10_000) / 100
  }
}
