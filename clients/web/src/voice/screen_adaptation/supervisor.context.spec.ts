import { expect, it } from 'vitest'
import { evaluateScreenAdaptation, initialScreenAdaptationState } from './supervisor'
import type { AdaptationCalibration, AdaptationSignal, AdaptationWindow } from './types'

const ladders = { motion: ['P1080_60', 'P720_60', 'P720_30'], text: ['P1080_60', 'P1080_30', 'P720_15'] } as const
const calibration: AdaptationCalibration = {
  evidence: { status: 'PASS', sha: 'b'.repeat(40) }, maxSignalAgeMs: 5000, maximumWindowGapMs: 5000,
  minIndependentSources: 2, pressureWindows: 2, recoveryDurationMs: 10000,
  minimumDwellMs: 5000, maxTransitionsPerGeneration: 4,
  ladders: { 'source-limited': ladders, 'encoder-cpu-thermal': ladders, 'publisher-uplink': ladders },
}
const sharedSignals = (at: number, condition: AdaptationSignal['condition']): AdaptationSignal[] =>
  (['sender-encoder', 'publisher-network'] as const).map(provenance => ({ provenance, bottleneck: 'publisher-uplink', condition, observedAtMs: at, publicationGeneration: 4 }))
function sample(id: string, at: number, signals = sharedSignals(at, 'pressure'), patch: Partial<AdaptationWindow> = {}): AdaptationWindow {
  return { id, observedAtMs: at, publicationGeneration: 4, content: 'motion', source: 'moving', visible: true, warmedUp: true,
    publication: 'sharing', subscribers: 2, signals, ...patch }
}

it('resets hysteresis across stale, hidden, static, paused, and no-subscriber windows', () => {
  let state = initialScreenAdaptationState('P1080_60', 'P1080_60', 4)
  state = evaluateScreenAdaptation(state, sample('one', 1000), 1000, calibration).state
  for (const [id, patch] of [
    ['hidden', { visible: false }], ['static', { source: 'static' as const }],
    ['paused', { publication: 'paused' as const }], ['nobody', { subscribers: 0 }],
  ] as const) state = evaluateScreenAdaptation(state, sample(id, 2000, undefined, patch), 2000, calibration).state
  const next = evaluateScreenAdaptation(state, sample('after-gap', 3000), 3000, calibration)
  expect(next.state.currentProfile).toBe('P1080_60')
  expect(next.decision.action).toBe('hold')
})

it('keeps a mixed weak/healthy receiver local to that receiver and ignores stale counters', () => {
  const weak: AdaptationSignal = { provenance: 'receiver-network', bottleneck: 'receiver-downlink-decode', condition: 'pressure', receiverId: 'weak', observedAtMs: 2000, publicationGeneration: 4 }
  const healthy: AdaptationSignal = { ...weak, condition: 'clear', receiverId: 'healthy' }
  const state = initialScreenAdaptationState('P1080_60', 'P1080_60', 4)
  const mixed = evaluateScreenAdaptation(state, sample('receivers', 2000, [weak, healthy]), 2000, calibration)
  expect(mixed.decision.reason).toBe('receiver-local-pressure')
  expect(mixed.state.currentProfile).toBe('P1080_60')
  const old = sharedSignals(1000, 'pressure')
  const stale = evaluateScreenAdaptation(mixed.state, sample('stale', 3000, old), 10000, calibration)
  expect(stale.state.currentProfile).toBe('P1080_60')
})

it('applies cooldown, waits for sustained recovery, and respects generation transition limits', () => {
  let state = initialScreenAdaptationState('P1080_60', 'P1080_60', 4)
  state = evaluateScreenAdaptation(state, sample('bad-1', 1000), 1000, calibration).state
  const down = evaluateScreenAdaptation(state, sample('bad-2', 2000), 2000, calibration)
  state = down.state
  state = evaluateScreenAdaptation(state, sample('bad-3', 3000), 3000, calibration).state
  const cooling = evaluateScreenAdaptation(state, sample('bad-4', 4000), 4000, calibration)
  expect(cooling.state.currentProfile).toBe('P720_60')
  state = evaluateScreenAdaptation(cooling.state, sample('bad-5', 7000), 7000, calibration).state
  const downAgain = evaluateScreenAdaptation(state, sample('bad-6', 8000), 8000, calibration)
  expect(downAgain.state.currentProfile).toBe('P720_30')
  state = evaluateScreenAdaptation(downAgain.state, sample('good-1', 9000, sharedSignals(9000, 'clear')), 9000, calibration).state
  state = evaluateScreenAdaptation(state, sample('good-2', 13000, sharedSignals(13000, 'clear')), 13000, calibration).state
  const good3 = evaluateScreenAdaptation(state, sample('good-3', 17000, sharedSignals(17000, 'clear')), 17000, calibration)
  expect(good3.state.currentProfile).toBe('P720_30')
  const tooEarly = evaluateScreenAdaptation(good3.state, sample('good-4', 18000, sharedSignals(18000, 'clear')), 18000, calibration)
  expect(tooEarly.state.currentProfile).toBe('P720_30')
  const recovered = evaluateScreenAdaptation(tooEarly.state, sample('good-5', 19000, sharedSignals(19000, 'clear')), 19000, calibration)
  expect(recovered.decision.profile).toBe('P720_60')
  expect(recovered.state.transitions).toBe(3)
})
