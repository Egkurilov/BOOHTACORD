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
  const age = sampledAt === undefined ? undefined : Date.now() - sampledAt
  return age !== undefined && Number.isFinite(age) && age >= 0 ? age : undefined
}
export function senderFields(diagnostics: ScreenDiagnostics, profile?: string | null) {
  const target = /^P(720|1080|1440)_(15|30|60)$/.exec(profile ?? '')
  const reason = diagnostics.adaptationReason
  const check = diagnostics.profileCheck
  const captureWidth = pixelDimension(check?.captureWidth), captureHeight = pixelDimension(check?.captureHeight)
  return {
    ...(check ? { profile_check_status: check.status, profile_check_reason: check.reason, profile_repair_attempts: check.attempts,
      ...(captureWidth && captureHeight ? { capture_width: captureWidth, capture_height: captureHeight } : {}),
      ...(bounded(check.captureFps, 240) === undefined ? {} : { capture_fps: check.captureFps }) } : {}),
    connection_quality: diagnostics.connectionQuality,
    ...(target ? { target_resolution: Number(target[1]), target_fps: Number(target[2]) } : {}),
    ...lossFields(diagnostics.packetLossPercent, diagnostics.packetLossWindowMs),
    ...(reason && ['none', 'cpu', 'bandwidth', 'other'].includes(reason) ? { adaptation_reason: reason } : {}),
    ...(diagnostics.sampledAt !== undefined ? { sample_age_ms: sampleAge(diagnostics.sampledAt) } : {}),
  }
}
