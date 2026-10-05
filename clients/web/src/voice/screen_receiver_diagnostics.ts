export interface ScreenReceiverSnapshot {
  bytesReceived?: number
  framesDecoded: number
  framesDropped: number
  jitter?: number
  packetsLost?: number
  packetsReceived?: number
  timestamp: number
}

export interface ScreenReceiverMetrics {
  decodedFrames?:number|null
  packetLossWindowMs?: number | null
  bitrateKbps: number | null
  decodedFps: number | null
  droppedFrames: number | null
  jitterMs: number | null
  packetsLost: number | null
  packetLossPercent: number | null
}

function rate(previous: number | undefined, current: number | undefined, elapsedMs: number, multiplier: number): number | null {
  if (previous === undefined || current === undefined || !Number.isFinite(previous) || !Number.isFinite(current) || !Number.isFinite(elapsedMs) || elapsedMs <= 0 || current < previous) return null
  return Math.round(((current - previous) * multiplier / elapsedMs) * 10) / 10
}

export function compareScreenReceiverStats(previous: ScreenReceiverSnapshot | null, current: ScreenReceiverSnapshot): ScreenReceiverMetrics {
  const elapsedMs = previous ? current.timestamp - previous.timestamp : 0
  const dropped = previous && elapsedMs > 0 && Number.isFinite(current.framesDropped) && current.framesDropped >= previous.framesDropped ? current.framesDropped - previous.framesDropped : null
  return {
    decodedFrames:Number.isSafeInteger(current.framesDecoded)&&current.framesDecoded>=0?current.framesDecoded:null,
    bitrateKbps: rate(previous?.bytesReceived, current.bytesReceived, elapsedMs, 8),
    decodedFps: rate(previous?.framesDecoded, current.framesDecoded, elapsedMs, 1000),
    droppedFrames: dropped,
    jitterMs: current.jitter !== undefined && Number.isFinite(current.jitter) && current.jitter >= 0 ? Math.round(current.jitter * 1000) : null,
    packetsLost: current.packetsLost !== undefined && Number.isFinite(current.packetsLost) && current.packetsLost >= 0 ? current.packetsLost : null,
    packetLossPercent: null,
  }
}
