import { screenProfile, type ScreenProfile } from '../screen_profile/policy'
import type { AdaptationCalibration, AdaptationContent, SharedBottleneck } from './types'

const bottlenecks: SharedBottleneck[] = ['source-limited', 'encoder-cpu-thermal', 'publisher-uplink']
const contents: AdaptationContent[] = ['motion', 'text']

export function validatedCalibration(value: AdaptationCalibration): boolean {
  if (value.evidence.status !== 'PASS' || !/^(?:[\da-f]{40}|[\da-f]{64})$/i.test(value.evidence.sha)) return false
  if (![value.maxSignalAgeMs, value.maximumWindowGapMs, value.recoveryDurationMs, value.minimumDwellMs].every(positive)) return false
  if (!Number.isInteger(value.minIndependentSources) || value.minIndependentSources < 2) return false
  if (!Number.isInteger(value.pressureWindows) || value.pressureWindows < 2) return false
  if (!Number.isInteger(value.maxTransitionsPerGeneration) || value.maxTransitionsPerGeneration < 1) return false
  try {
    return bottlenecks.every(kind => contents.every(content => validLadder(value.ladders[kind][content])))
  } catch { return false }
}

export function profileStep(value: AdaptationCalibration, kind: SharedBottleneck, content: AdaptationContent,
  current: ScreenProfile, ceiling: ScreenProfile, direction: 'down' | 'up'): ScreenProfile | undefined {
  const ladder = value.ladders[kind][content], index = ladder.indexOf(current), cap = ladder.indexOf(ceiling)
  if (index < 0 || cap < 0 || index < cap) return undefined
  const target = direction === 'down' ? ladder[index + 1] : ladder[index - 1]
  if (!target || (direction === 'up' && index - 1 < cap)) return undefined
  return target
}

function positive(value: number): boolean { return Number.isFinite(value) && value > 0 }
function validLadder(ladder: readonly ScreenProfile[]): boolean {
  if (ladder.length < 2 || new Set(ladder).size !== ladder.length) return false
  try {
    const metrics = ladder.map(profile => screenProfile(profile))
    return metrics.every((current, index) => index === 0 ||
      (current.height <= metrics[index - 1].height && current.frameRate <= metrics[index - 1].frameRate))
  } catch { return false }
}
