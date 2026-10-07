import type { ScreenDiagnostics } from '../screen_diagnostics'
import type { ScreenClientReportInput, ScreenMeasurementFields } from './types'
import { bounded } from './fields'

export function senderMeasurements(d: ScreenDiagnostics): ScreenMeasurementFields {
  const layer = d.selectedLayer
  const window = bounded(layer?.windowMs, 10000)
  if (!layer || !window) return { stats_source: 'unsupported', collection_state: d.collectionState ?? 'unavailable' }
  const fields: ScreenMeasurementFields = { stats_source: 'webrtc_interval', stats_window_ms: window,
    collection_state: typeof document !== 'undefined' && document.visibilityState === 'hidden' ? 'hidden' : d.collectionState ?? 'unknown' }
  const candidates = { total_bitrate_kbps: d.totalBitrateBps === undefined ? undefined : d.totalBitrateBps / 1000,
    selected_layer_bitrate_kbps: layer.bitrateBps === null ? undefined : layer.bitrateBps / 1000,
    retransmitted_bitrate_kbps: layer.retransmittedBps === null ? undefined : layer.retransmittedBps / 1000,
    encode_ms_per_frame: layer.encodeMsPerFrame, nack_per_second: layer.nackPerSecond,
    pli_per_second: layer.pliPerSecond, fir_per_second: layer.firPerSecond }
  for (const [key, value] of Object.entries(candidates)) {
    const valid = bounded(value, key === 'encode_ms_per_frame' ? 60000 : key.endsWith('per_second') ? 1000000 : 100000)
    if (valid !== undefined) Object.assign(fields, { [key]: valid })
  }
  return fields
}

export function receiverMeasurements(input: ScreenClientReportInput): ScreenMeasurementFields {
  const m = input.receiverMetrics
  const fields: ScreenMeasurementFields = { presentation_source: input.presentationSource,
    stats_source: m?.statsWindowMs ? 'webrtc_interval' : 'unsupported', collection_state: m?.collectionState ?? 'unavailable' }
  const first = bounded(input.firstFrameMs, 86400000)
  if (first !== undefined && fields.presentation_source === 'web_rvfc') fields.first_frame_ms = first
  const count = bounded(m?.freezeCount, 1e9), duration = bounded(m?.freezeDurationMs, 86400000)
  if (count !== undefined && Number.isInteger(count)) { fields.freeze_count = count; fields.stats_source = 'webrtc_interval' }
  if (duration !== undefined) { fields.freeze_duration_ms = duration; fields.stats_source = 'webrtc_interval' }
  if (!m?.statsWindowMs) return fields
  fields.stats_window_ms = m.statsWindowMs
  const candidates = { decode_ms_per_frame: m.decodeMsPerFrame, jitter_buffer_ms_per_frame: m.jitterBufferMsPerFrame,
    nack_per_second: m.nackPerSecond, pli_per_second: m.pliPerSecond, fir_per_second: m.firPerSecond,
    freeze_count: m.freezeCount, freeze_duration_ms: m.freezeDurationMs }
  for (const [key, value] of Object.entries(candidates)) {
    const valid = bounded(value, key === 'freeze_count' ? 1e9 : key === 'freeze_duration_ms' ? 86400000 : key.endsWith('per_second') ? 1000000 : 60000)
    if (valid !== undefined) Object.assign(fields, { [key]: valid })
  }
  return fields
}
