export type VoiceConnectionQuality = 'EXCELLENT' | 'GOOD' | 'POOR' | 'LOST' | 'UNKNOWN'

export interface VoiceConnectionStats {
  quality: VoiceConnectionQuality
  pingMs: number | null
}

interface AudioRTCStat {
  id?: string
  type?: string
  roundTripTime?: unknown
  selectedCandidatePairId?: string
  currentRoundTripTime?: unknown
  selected?: boolean
  nominated?: boolean
  state?: string
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
  const items = [...reports ?? []]
  for (const report of items) {
    if (report.type !== 'remote-inbound-rtp') continue
    const seconds = report.roundTripTime
    if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0 || seconds > 60) continue
    pingMs = Math.round(seconds * 1000)
    break
  }
  if (pingMs === null) {
    const selected = new Set(items.filter((item) => item.type === 'transport').map((item) => item.selectedCandidatePairId).filter(Boolean))
    for (const item of items) {
      if (item.type !== 'candidate-pair' || !(selected.size ? selected.has(item.id) : item.selected || (item.nominated && item.state === 'succeeded'))) continue
      const seconds = item.currentRoundTripTime
      if (typeof seconds === 'number' && Number.isFinite(seconds) && seconds >= 0 && seconds <= 60) { pingMs = Math.round(seconds * 1000); break }
    }
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
