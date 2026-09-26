import { apiBaseUrl } from '../config/runtime'

export interface AdminScreenSample {
  platform: 'ios_web' | 'android_web' | 'desktop_web' | 'android_native' | 'desktop_native'
  direction: 'sender' | 'receiver'
  state: 'waiting_subscription' | 'waiting_first_frame' | 'playing' | 'stalled'
  sampled_at_utc: string
  encoded_fps?: number
  decoded_fps?: number
  presented_fps?: number
  bitrate_kbps?: number
  jitter_ms?: number
  packets_lost?: number
  dropped_frames?: number
  rtt_ms?: number
}

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Некорректные показатели медиа.')
  return value as Record<string, unknown>
}
function choice<T extends string>(value: unknown, choices: readonly T[]): T {
  if (typeof value !== 'string' || !choices.includes(value as T)) throw new Error('Некорректные показатели медиа.')
  return value as T
}
function optionalNumber(value: unknown, maximum: number): number | undefined {
  if (value === undefined || value === null) return undefined
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > maximum) throw new Error('Некорректные показатели медиа.')
  return value
}
function sample(value: unknown): AdminScreenSample {
  const outer = record(value); const report = record(outer.report)
  if (typeof outer.sampled_at_utc !== 'string' || !Number.isFinite(Date.parse(outer.sampled_at_utc))) throw new Error('Некорректные показатели медиа.')
  const parsed: AdminScreenSample = {
    platform: choice(report.platform, ['ios_web', 'android_web', 'desktop_web', 'android_native', 'desktop_native']),
    direction: choice(report.direction, ['sender', 'receiver']),
    state: choice(report.state, ['waiting_subscription', 'waiting_first_frame', 'playing', 'stalled']),
    sampled_at_utc: outer.sampled_at_utc,
  }
  for (const [field, maximum] of [['encoded_fps', 240], ['decoded_fps', 240], ['presented_fps', 240], ['bitrate_kbps', 100000], ['jitter_ms', 60000], ['rtt_ms', 60000], ['packets_lost', 1000000000], ['dropped_frames', 1000000000]] as const) {
    const number = optionalNumber(report[field], maximum)
    if (number !== undefined) parsed[field] = number
  }
  return parsed
}

export async function listAdminScreenMetrics(request: typeof fetch = fetch): Promise<AdminScreenSample[]> {
  const response = await request(`${apiBaseUrl}/admin/screen-metrics`, { credentials: 'same-origin', headers: { accept: 'application/json' }, cache: 'no-store' })
  if (!response.ok) throw new Error('Не удалось загрузить показатели медиа.')
  const payload = record(await response.json())
  if (!Array.isArray(payload.samples) || payload.samples.length > 10) throw new Error('Некорректные показатели медиа.')
  return payload.samples.map(sample)
}
