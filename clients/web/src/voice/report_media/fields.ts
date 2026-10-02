import type { ScreenDiagnostics } from '../screen_diagnostics'

export function bounded(value: number | null | undefined, maximum: number): number | undefined {
  return value !== null && value !== undefined && Number.isFinite(value) && value >= 0 && value <= maximum ? value : undefined
}
export function pixelDimension(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) && value >= 1 && value <= 8192 ? Math.round(value) : undefined
}
export function lossFields(percent: number | null | undefined, duration: number | null | undefined) {
  const loss = bounded(percent, 100)
  const window = bounded(duration, 12000)
  return loss !== undefined && window !== undefined && window >= 9000 ? { packet_loss_percent: loss, packet_loss_window_ms: window } : {}
}
export function sampleAge(sampledAt: number | undefined): number | undefined {
  return sampledAt === undefined ? undefined : Math.max(0, Date.now() - sampledAt)
}
export function senderFields(diagnostics: ScreenDiagnostics, profile?: string | null) {
  const target = /^P(720|1080|1440)_(15|30|60)$/.exec(profile ?? '')
  const reason = diagnostics.adaptationReason
  return {
    connection_quality: diagnostics.connectionQuality,
    ...(target ? { target_resolution: Number(target[1]), target_fps: Number(target[2]) } : {}),
    ...lossFields(diagnostics.packetLossPercent, diagnostics.packetLossWindowMs),
    ...(reason && ['none', 'cpu', 'bandwidth', 'other'].includes(reason) ? { adaptation_reason: reason } : {}),
    ...(diagnostics.sampledAt !== undefined ? { sample_age_ms: sampleAge(diagnostics.sampledAt) } : {}),
  }
}
