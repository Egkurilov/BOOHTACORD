import { describe, expect, it } from 'vitest'
import { evaluateScreenAdaptation, initialScreenAdaptationState } from './supervisor'
import type { AdaptationCalibration, AdaptationSignal, AdaptationWindow } from './types'

const calibration: AdaptationCalibration = {
  evidence: { status: 'PASS', sha: 'a'.repeat(40) }, maxSignalAgeMs: 5000, maximumWindowGapMs: 5000,
  minIndependentSources: 2, pressureWindows: 2, recoveryDurationMs: 10000,
  minimumDwellMs: 5000, maxTransitionsPerGeneration: 4,
  ladders: {
    'source-limited': { motion: ['P1080_60', 'P720_60', 'P720_30'], text: ['P1080_60', 'P1080_30', 'P720_15'] },
    'encoder-cpu-thermal': { motion: ['P1080_60', 'P720_60', 'P720_30'], text: ['P1080_60', 'P1080_30', 'P720_15'] },
    'publisher-uplink': { motion: ['P1080_60', 'P720_60', 'P720_30'], text: ['P1080_60', 'P1080_30', 'P720_15'] },
  },
}

function signals(at: number, kind: AdaptationSignal['bottleneck'] = 'publisher-uplink', condition: AdaptationSignal['condition'] = 'pressure'): AdaptationSignal[] {
  return (['sender-encoder', 'publisher-network'] as const).map(provenance => ({ provenance, bottleneck: kind, condition, observedAtMs: at, publicationGeneration: 9 }))
}
function window(id: string, at: number, overrides: Partial<AdaptationWindow> = {}): AdaptationWindow {
  return { id, observedAtMs: at, publicationGeneration: 9, content: 'motion', source: 'moving', visible: true, warmedUp: true,
    publication: 'sharing', subscribers: 2, signals: signals(at), ...overrides }
}

describe('screen adaptation pressure policy', () => {
  it('stays inert until a validated calibration is explicitly supplied', () => {
    const state = initialScreenAdaptationState('P1080_60', 'P1080_60', 9)
    const result = evaluateScreenAdaptation(state, window('w1', 1000), 1000)
    expect(result.decision.reason).toBe('disabled-unvalidated')
    expect(result.state.currentProfile).toBe('P1080_60')
  })

  it('requires distinct windows with concordant fresh publisher evidence before one video downgrade', () => {
    let state = initialScreenAdaptationState('P1080_60', 'P1080_60', 9)
    let result = evaluateScreenAdaptation(state, window('w1', 1000), 1000, calibration)
    expect(result.decision.action).toBe('hold')
    state = result.state
    result = evaluateScreenAdaptation(state, window('w2', 2000), 2000, calibration)
    expect(result.decision).toMatchObject({ action: 'change-profile', profile: 'P720_60', priority: 'voice-first' })
    expect(result.state.transitions).toBe(1)
  })

  it('uses a text ladder that preserves resolution before reducing frame rate', () => {
    const text = initialScreenAdaptationState('P1080_60', 'P1080_60', 9)
    const first = evaluateScreenAdaptation(text, window('text-1', 1000, { content: 'text' }), 1000, calibration)
    const moved = evaluateScreenAdaptation(first.state, window('text-2', 2000, { content: 'text' }), 2000, calibration)
    expect(moved.decision.profile).toBe('P1080_30')
  })

  it('recovers only up to the ceiling explicitly selected by the user', () => {
    let state = initialScreenAdaptationState('P720_60', 'P720_60', 9)
    state = evaluateScreenAdaptation(state, window('limit-bad-1', 1000), 1000, calibration).state
    state = evaluateScreenAdaptation(state, window('limit-bad-2', 2000), 2000, calibration).state
    expect(state.currentProfile).toBe('P720_30')
    state = evaluateScreenAdaptation(state, window('limit-good-1', 3000, { signals: signals(3000, 'publisher-uplink', 'clear') }), 3000, calibration).state
    state = evaluateScreenAdaptation(state, window('limit-good-2', 8000, { signals: signals(8000, 'publisher-uplink', 'clear') }), 8000, calibration).state
    state = evaluateScreenAdaptation(state, window('limit-good-3', 13000, { signals: signals(13000, 'publisher-uplink', 'clear') }), 13000, calibration).state
    expect(state.currentProfile).toBe('P720_60')
    state = evaluateScreenAdaptation(state, window('limit-good-4', 18000, { signals: signals(18000, 'publisher-uplink', 'clear') }), 18000, calibration).state
    state = evaluateScreenAdaptation(state, window('limit-good-5', 23000, { signals: signals(23000, 'publisher-uplink', 'clear') }), 23000, calibration).state
    const capped = evaluateScreenAdaptation(state, window('limit-good-6', 28000, { signals: signals(28000, 'publisher-uplink', 'clear') }), 28000, calibration)
    expect(capped.decision.reason).toBe('user-ceiling')
    expect(capped.state.currentProfile).toBe('P720_60')
  })
})
