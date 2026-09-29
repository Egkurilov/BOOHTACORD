export type VoiceConnectionQuality = 'EXCELLENT' | 'GOOD' | 'POOR' | 'LOST' | 'UNKNOWN'

export interface VoiceConnectionStats {
  quality: VoiceConnectionQuality
  pingMs: number | null
}

interface AudioRTCStat {
  type?: string
  roundTripTime?: unknown
}

export function voiceConnectionQuality(value: unknown): VoiceConnectionQuality {
  switch (typeof value === 'string' ? value.toUpperCase() : '') {
    case 'EXCELLENT': return 'EXCELLENT'
    case 'GOOD': return 'GOOD'
    case 'POOR': return 'POOR'
    case 'LOST': return 'LOST'
    default: return 'UNKNOWN'
  }
}

export function readVoiceConnectionStats(
  quality: unknown,
  reports: Iterable<AudioRTCStat> | undefined,
): VoiceConnectionStats {
  let pingMs: number | null = null
  for (const report of reports ?? []) {
    if (report.type !== 'remote-inbound-rtp') continue
    const seconds = report.roundTripTime
    if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0 || seconds > 60) continue
    pingMs = Math.round(seconds * 1000)
    break
  }
  return { quality: voiceConnectionQuality(quality), pingMs }
}

export function voiceConnectionQualityLabel(quality: VoiceConnectionQuality): string {
  return ({
    EXCELLENT: 'Отличное',
    GOOD: 'Хорошее',
    POOR: 'Низкое',
    LOST: 'Потеряно',
    UNKNOWN: 'Нет данных',
  })[quality]
}
