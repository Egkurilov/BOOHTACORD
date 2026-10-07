export interface RawScreenLayerStats {
  id?: string
  timestamp: number
  ssrc?: number
  rid?: string
  codec?: string
  active?: boolean
  frameWidth?: number
  frameHeight?: number
  framesEncoded?: number
  bytesSent?: number
  retransmittedBytesSent?: number
  packetsSent?: number
  packetsLost?: number
  nackCount?: number
  pliCount?: number
  firCount?: number
  totalEncodeTime?: number
  qualityLimitationReason?: string
}

export interface ScreenLayerDiagnostics {
  id: string
  rid?: string
  codec?: string
  state: 'ACTIVE' | 'INACTIVE' | 'UNKNOWN' | 'STALE'
  frameWidth?: number
  frameHeight?: number
  framesPerSecond: number | null
  bitrateBps: number | null
  retransmittedBps: number | null
  nackPerSecond: number | null
  pliPerSecond: number | null
  firPerSecond: number | null
  encodeMsPerFrame: number | null
  packetLossPercent: number | null
  qualityLimitationReason?: string
}

interface PreviousLayer extends RawScreenLayerStats { key: string }
const maximumLayers = 8
const maximumAgeMs = 10_000
const counter = (value: number | undefined): boolean => value !== undefined && Number.isFinite(value) && value >= 0

export class ScreenSenderLayerSampler {
  private previous = new Map<string, PreviousLayer>()

  clear(): void { this.previous.clear() }

  sample(rows: RawScreenLayerStats[], now: number): { layers: ScreenLayerDiagnostics[]; selected: ScreenLayerDiagnostics | null } {
    const next = new Map<string, PreviousLayer>()
    const layers = rows.slice(0, maximumLayers).map((row, index) => {
      const key = row.id ?? `${row.ssrc ?? ''}:${row.rid ?? ''}:${index}`
      const previous = this.previous.get(key)
      const age = now - row.timestamp
      const elapsed = previous ? row.timestamp - previous.timestamp : 0
      const validInterval = Boolean(previous && elapsed > 0 && elapsed <= maximumAgeMs && age >= 0 && age <= maximumAgeMs)
      const delta = (current: number | undefined, before: number | undefined): number | null =>
        validInterval && counter(current) && counter(before) && current! >= before! ? current! - before! : null
      const frames = delta(row.framesEncoded, previous?.framesEncoded)
      const bytes = delta(row.bytesSent, previous?.bytesSent)
      const retransmitted = delta(row.retransmittedBytesSent, previous?.retransmittedBytesSent)
      const sent = delta(row.packetsSent, previous?.packetsSent)
      const lost = delta(row.packetsLost, previous?.packetsLost)
      const nacks = delta(row.nackCount, previous?.nackCount)
      const plis = delta(row.pliCount, previous?.pliCount)
      const firs = delta(row.firCount, previous?.firCount)
      const encodeTime = delta(row.totalEncodeTime, previous?.totalEncodeTime)
      const stale = !Number.isFinite(row.timestamp) || age < 0 || age > maximumAgeMs
      const progressed = [frames, bytes, sent].some(value => value !== null && value > 0)
      const state = stale ? 'STALE' : row.active === false ? 'INACTIVE' : row.active === true || progressed ? 'ACTIVE' : 'UNKNOWN'
      const rate = (value: number | null, multiplier: number): number | null => state === 'ACTIVE' && validInterval && value !== null ? value * multiplier / elapsed : null
      const packetLossPercent = state === 'ACTIVE' && sent !== null && lost !== null && sent + lost > 0
        ? lost * 100 / (sent + lost) : null
      if (Number.isFinite(row.timestamp)) next.set(key, { ...row, key })
      return {
        id: key, ...(row.rid ? { rid: row.rid } : {}), ...(row.codec ? { codec: row.codec } : {}), state,
        ...(counter(row.frameWidth) && row.frameWidth! > 0 ? { frameWidth: row.frameWidth } : {}),
        ...(counter(row.frameHeight) && row.frameHeight! > 0 ? { frameHeight: row.frameHeight } : {}),
        framesPerSecond: rate(frames, 1000), bitrateBps: rate(bytes, 8000), retransmittedBps: rate(retransmitted, 8000), packetLossPercent,
        nackPerSecond: rate(nacks, 1000), pliPerSecond: rate(plis, 1000), firPerSecond: rate(firs, 1000),
        encodeMsPerFrame: frames !== null && frames > 0 && encodeTime !== null ? encodeTime * 1000 / frames : null,
        ...(row.qualityLimitationReason ? { qualityLimitationReason: row.qualityLimitationReason } : {}),
      } satisfies ScreenLayerDiagnostics
    })
    this.previous = next
    const selected = layers.filter(layer => layer.state === 'ACTIVE').sort((a, b) =>
      (b.frameWidth ?? 0) * (b.frameHeight ?? 0) - (a.frameWidth ?? 0) * (a.frameHeight ?? 0))[0] ?? null
    return { layers, selected }
  }
}
