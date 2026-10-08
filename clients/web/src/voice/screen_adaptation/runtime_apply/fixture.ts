import { setup } from '../../screen_publisher/adapter_fixture'
import type { AdaptationCalibration, AdaptationSignal, AdaptationWindow } from '../types'
import { ScreenAdaptationRuntime } from './runtime'

const ladders = { motion: ['P1080_60', 'P720_60', 'P720_30'], text: ['P1080_60', 'P1080_30', 'P720_15'] } as const
// Synthetic fixture calibration; this is not device or release evidence.
export const calibration: AdaptationCalibration = {
  evidence: { status: 'PASS', sha: 'b'.repeat(40) }, maxSignalAgeMs: 5000, maximumWindowGapMs: 5000,
  minIndependentSources: 2, pressureWindows: 2, recoveryDurationMs: 10000, minimumDwellMs: 5000,
  maxTransitionsPerGeneration: 4,
  ladders: { 'source-limited': ladders, 'encoder-cpu-thermal': ladders, 'publisher-uplink': ladders },
}
export async function fixture() {
  const value = setup()
  await value.adapter.start('P1080_60')
  const runtime = new ScreenAdaptationRuntime(value.adapter, { enabled: true, calibration })
  return { ...value, runtime }
}
export function window(at: number, generation: number, patch: Partial<AdaptationWindow> = {}): AdaptationWindow {
  const signals: AdaptationSignal[] = (['sender-encoder', 'publisher-network'] as const)
    .map(provenance => ({ provenance, bottleneck: 'publisher-uplink', condition: 'pressure', observedAtMs: at, publicationGeneration: generation }))
  return { id: `window-${at}`, observedAtMs: at, publicationGeneration: generation, content: 'motion', source: 'moving',
    visible: true, warmedUp: true, publication: 'sharing', subscribers: 2, signals, ...patch }
}
