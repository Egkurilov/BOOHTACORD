import { profileStep, validatedCalibration } from './profile_ladder'
import type { AdaptationCalibration, AdaptationDecision, AdaptationResult, AdaptationSignal, AdaptationState, AdaptationWindow, SharedBottleneck } from './types'

export function initialScreenAdaptationState(currentProfile: AdaptationState['currentProfile'], ceilingProfile: AdaptationState['ceilingProfile'], publicationGeneration: number): AdaptationState {
  return { currentProfile, ceilingProfile, publicationGeneration, pressureWindows: 0, transitions: 0 }
}

export function evaluateScreenAdaptation(state: AdaptationState, window: AdaptationWindow, now: number,
  calibration?: AdaptationCalibration): AdaptationResult {
  if (!calibration || !validatedCalibration(calibration)) return hold(state, 'disabled-unvalidated')
  if (!window.id || !Number.isFinite(now) || !Number.isFinite(window.observedAtMs) || window.observedAtMs > now || now - window.observedAtMs > calibration.maxSignalAgeMs) return hold(reset(state), 'stale-window')
  if (window.id === state.lastWindowId || (state.lastWindowAtMs !== undefined && window.observedAtMs <= state.lastWindowAtMs)) return hold(state, 'duplicate-window')
  const seen = { ...state, lastWindowId: window.id, lastWindowAtMs: window.observedAtMs }
  const gap = state.lastWindowAtMs !== undefined && window.observedAtMs - state.lastWindowAtMs > calibration.maximumWindowGapMs
  const changedContent = Boolean(state.trendContent && state.trendContent !== window.content)
  const continuous = gap || changedContent ? reset(seen) : seen
  continuous.trendContent = window.content
  if (window.publicationGeneration !== state.publicationGeneration) return hold(reset(continuous), 'stale-generation')
  if (!window.visible || !window.warmedUp || window.source !== 'moving' || window.publication !== 'sharing' || window.subscribers === 0) {
    return hold(reset(continuous), !window.visible ? 'hidden' : !window.warmedUp ? 'warm-up' : window.source !== 'moving' ? 'source-not-moving' : window.publication !== 'sharing' ? 'publication-inactive' : 'no-subscribers')
  }
  if (window.subscribers === null || !Number.isInteger(window.subscribers) || window.subscribers < 0) return hold(reset(continuous), 'unknown-subscribers')
  const fresh = window.signals.filter(signal => signalFresh(signal, window, now, calibration))
  if (!fresh.length) return hold(reset(continuous), window.signals.length ? 'stale-signals' : 'unknown-bottleneck')
  const observedKinds = new Set(fresh.filter(signal => signal.condition === 'pressure' && isShared(signal.bottleneck)).map(signal => signal.bottleneck))
  if (observedKinds.size > 1) return hold(reset(continuous), 'mixed-bottlenecks')
  const pressured = concordant(fresh, calibration, 'pressure')
  if (pressured.length > 1) return hold(reset(continuous), 'mixed-bottlenecks')
  if (!pressured.length && fresh.some(signal => isReceiverLocal(signal) && signal.condition === 'pressure')) return hold(reset(continuous), 'receiver-local-pressure')
  if (pressured.length === 1) return downgrade(continuous, window, now, calibration, pressured[0])
  if (fresh.some(signal => isShared(signal.bottleneck) && signal.condition === 'pressure')) return hold(reset(continuous), 'bottleneck-unconfirmed')
  return recover(continuous, window, now, calibration, fresh)
}

function downgrade(state: AdaptationState, window: AdaptationWindow, now: number, calibration: AdaptationCalibration, kind: SharedBottleneck): AdaptationResult {
  const count = state.pressureBottleneck === kind ? state.pressureWindows + 1 : 1
  const watching = { ...state, pressureBottleneck: kind, pressureWindows: count, healthySinceMs: undefined }
  if (count < calibration.pressureWindows) return hold(watching, 'awaiting-confirmation', kind)
  if (!transitionAllowed(state, now, calibration)) return hold(reset(watching), state.transitions >= calibration.maxTransitionsPerGeneration ? 'transition-limit' : 'cooldown', kind)
  const target = profileStep(calibration, kind, window.content, state.currentProfile, state.ceilingProfile, 'down')
  if (!target) return hold(reset(watching), 'profile-floor-or-ceiling', kind)
  return transition(watching, target, kind, window.observedAtMs, 'downgrade-pressure')
}

function recover(state: AdaptationState, window: AdaptationWindow, now: number, calibration: AdaptationCalibration, signals: readonly AdaptationSignal[]): AdaptationResult {
  const kind = state.pressureBottleneck
  if (!kind || concordant(signals, calibration, 'pressure').length) return hold(reset(state), 'no-concordant-bottleneck')
  if (signals.some(signal => signal.bottleneck === kind && signal.condition === 'pressure')) return hold(reset(state), 'recovery-unconfirmed', kind)
  const clear = signals.filter(signal => signal.bottleneck === kind && signal.condition === 'clear' && !signal.receiverId)
  if (new Set(clear.map(signal => signal.provenance)).size < calibration.minIndependentSources) return hold(reset(state), 'recovery-unconfirmed', kind)
  const since = state.healthySinceMs ?? window.observedAtMs, healthy = { ...state, pressureWindows: 0, healthySinceMs: since }
  if (window.observedAtMs - since < calibration.recoveryDurationMs) return hold(healthy, 'recovery-window', kind)
  if (!transitionAllowed(state, now, calibration)) return hold(healthy, state.transitions >= calibration.maxTransitionsPerGeneration ? 'transition-limit' : 'cooldown', kind)
  const target = profileStep(calibration, kind, window.content, state.currentProfile, state.ceilingProfile, 'up')
  if (!target) return hold(healthy, 'user-ceiling', kind)
  return transition(healthy, target, kind, window.observedAtMs, 'recovered')
}

function signalFresh(signal: AdaptationSignal, window: AdaptationWindow, now: number, calibration: AdaptationCalibration): boolean {
  return signal.publicationGeneration === window.publicationGeneration && signal.observedAtMs <= window.observedAtMs &&
    now >= signal.observedAtMs && now - signal.observedAtMs <= calibration.maxSignalAgeMs &&
    (!isReceiverLocal(signal) || Boolean(signal.receiverId))
}
function isReceiverLocal(signal: AdaptationSignal): boolean { return signal.bottleneck === 'receiver-downlink-decode' || signal.bottleneck === 'rendering' }
function isShared(value: AdaptationSignal['bottleneck']): value is SharedBottleneck { return value === 'source-limited' || value === 'encoder-cpu-thermal' || value === 'publisher-uplink' }
function concordant(signals: readonly AdaptationSignal[], calibration: AdaptationCalibration, condition: 'pressure' | 'clear'): SharedBottleneck[] {
  const kinds: SharedBottleneck[] = ['source-limited', 'encoder-cpu-thermal', 'publisher-uplink']
  return kinds.filter(kind => new Set(signals.filter(signal => signal.bottleneck === kind && signal.condition === condition && !signal.receiverId).map(signal => signal.provenance)).size >= calibration.minIndependentSources)
}
function transitionAllowed(state: AdaptationState, now: number, calibration: AdaptationCalibration): boolean {
  return state.transitions < calibration.maxTransitionsPerGeneration && (state.lastTransitionAtMs === undefined || now - state.lastTransitionAtMs >= calibration.minimumDwellMs)
}
function transition(state: AdaptationState, profile: AdaptationState['currentProfile'], kind: SharedBottleneck, at: number, reason: string): AdaptationResult {
  return { state: { ...state, currentProfile: profile, lastTransitionAtMs: at, pressureWindows: 0, healthySinceMs: undefined, transitions: state.transitions + 1 },
    decision: { action: 'change-profile', reason, profile, bottleneck: kind, priority: 'voice-first' } }
}
function reset(state: AdaptationState): AdaptationState { return { ...state, pressureWindows: 0, healthySinceMs: undefined } }
function hold(state: AdaptationState, reason: string, bottleneck?: SharedBottleneck): AdaptationResult {
  const decision: AdaptationDecision = { action: 'hold', reason, ...(bottleneck ? { bottleneck } : {}) }
  return { state, decision }
}
