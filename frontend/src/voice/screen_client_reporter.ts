import { apiBaseUrl } from '../config/runtime'
import type { ScreenReceiverMetrics } from './screen_receiver_diagnostics'
import type { ScreenDiagnostics } from './screen_diagnostics'

export type WebPlatform = 'ios_web' | 'android_web' | 'desktop_web'
export interface ScreenClientReport {
  platform: WebPlatform
  direction: 'sender' | 'receiver'
  state: 'waiting_subscription' | 'waiting_first_frame' | 'playing' | 'stalled'
  presented_fps?: number
  encoded_fps?: number
  decoded_fps?: number
  bitrate_kbps?: number
  jitter_ms?: number
  packets_lost?: number
  dropped_frames?: number
  rtt_ms?: number
}
export interface ScreenClientReportInput {
  platform: WebPlatform
  selected: boolean
  hasTrack: boolean
  videoReady: boolean
  playbackFps: number | null
  receiverMetrics: ScreenReceiverMetrics | null
}

export function webPlatform(userAgent: string): WebPlatform {
  if (/iPhone|iPad|iPod/i.test(userAgent)) return 'ios_web'
  if (/Android/i.test(userAgent)) return 'android_web'
  return 'desktop_web'
}

function bounded(value: number | null | undefined, maximum: number): number | undefined {
  return value !== null && value !== undefined && Number.isFinite(value) && value >= 0 && value <= maximum ? value : undefined
}

export function buildScreenClientReport(input: ScreenClientReportInput): ScreenClientReport | null {
  if (!input.selected) return null
  const presented = bounded(input.playbackFps, 240)
  const decoded = bounded(input.receiverMetrics?.decodedFps, 240)
  const bitrate = bounded(input.receiverMetrics?.bitrateKbps, 100000)
  const jitter = bounded(input.receiverMetrics?.jitterMs, 60000)
  const lost = bounded(input.receiverMetrics?.packetsLost, 1000000000)
  const dropped = bounded(input.receiverMetrics?.droppedFrames, 1000000000)
  const state = !input.hasTrack ? 'waiting_subscription' : !input.videoReady ? 'waiting_first_frame' : presented === 0 ? 'stalled' : 'playing'
  return {
    platform: input.platform, direction: 'receiver', state,
    ...(presented === undefined ? {} : { presented_fps: presented }),
    ...(decoded === undefined ? {} : { decoded_fps: decoded }),
    ...(bitrate === undefined ? {} : { bitrate_kbps: bitrate }),
    ...(jitter === undefined ? {} : { jitter_ms: jitter }),
    ...(lost === undefined ? {} : { packets_lost: Math.floor(lost) }),
    ...(dropped === undefined ? {} : { dropped_frames: Math.floor(dropped) }),
  }
}

export function buildSenderScreenReport(platform: WebPlatform, diagnostics: ScreenDiagnostics): ScreenClientReport | null {
  if (diagnostics.source === 'ENDED') return null
  const encoded = bounded(diagnostics.measured?.framesPerSecond, 240)
  const bitrate = bounded(diagnostics.bitrateBps === undefined ? undefined : diagnostics.bitrateBps / 1000, 100000)
  const rtt = bounded(diagnostics.roundTripTimeMs, 60000)
  return {
    platform, direction: 'sender', state: diagnostics.source === 'ACTIVE' ? 'playing' : 'waiting_first_frame',
    ...(encoded === undefined ? {} : { encoded_fps: encoded }),
    ...(bitrate === undefined ? {} : { bitrate_kbps: Math.round(bitrate * 10) / 10 }),
    ...(rtt === undefined ? {} : { rtt_ms: rtt }),
  }
}

export async function postScreenClientReport(report: ScreenClientReport, request: typeof fetch = fetch): Promise<void> {
  const response = await request(`${apiBaseUrl}/voice/screen-metrics`, {
    method: 'POST', credentials: 'same-origin', headers: { 'content-type': 'application/json', accept: 'application/json' }, body: JSON.stringify(report),
  })
  if (!response.ok) throw new Error('screen metrics rejected')
}

export function startScreenClientReporting(read: () => ScreenClientReport | null, visible: () => boolean): () => void {
  let busy = false
  const interval = globalThis.setInterval(() => {
    if (busy || !visible()) return
    const report = read()
    if (!report) return
    busy = true
    void postScreenClientReport(report).catch(() => {}).finally(() => { busy = false })
  }, 5000)
  return () => globalThis.clearInterval(interval)
}
