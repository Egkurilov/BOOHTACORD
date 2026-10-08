import 'types.dart';
import 'state.dart';
import 'calibration.dart';
import 'signals.dart';
import 'transitions.dart';

ScreenAdaptationResult evaluateScreenAdaptation(
  ScreenAdaptationState previous,
  ScreenAdaptationWindow window,
  double now,
  ScreenAdaptationCalibration? calibration,
) {
  final state = ScreenAdaptationState.copy(previous);
  ScreenAdaptationResult hold(String reason, {bool reset = false}) {
    if (reset) state.resetTrend();
    return ScreenAdaptationResult(state, reason);
  }

  if (calibration == null || !calibration.valid) {
    return hold('disabled-unvalidated');
  }
  if (window.id.isEmpty ||
      !now.isFinite ||
      !window.observedAtMs.isFinite ||
      window.observedAtMs > now ||
      now - window.observedAtMs > calibration.maxSignalAgeMs) {
    return hold('stale-window', reset: true);
  }
  if (window.id == state.lastWindowId ||
      state.lastWindowAtMs != null &&
          window.observedAtMs <= state.lastWindowAtMs!) {
    return hold('duplicate-window');
  }
  if (state.lastWindowAtMs != null &&
          window.observedAtMs - state.lastWindowAtMs! >
              calibration.maximumWindowGapMs ||
      state.trendContent != null && state.trendContent != window.content) {
    state.resetTrend();
  }
  state.lastWindowId = window.id;
  state.lastWindowAtMs = window.observedAtMs;
  state.trendContent = window.content;
  if (window.generation != state.generation) {
    return hold('stale-generation', reset: true);
  }
  if (!window.visible ||
      !window.warmedUp ||
      window.source != ScreenAdaptationSource.moving ||
      window.publication != ScreenAdaptationPublication.sharing ||
      window.subscribers == 0) {
    return hold('inactive-window', reset: true);
  }
  if (window.subscribers == null || window.subscribers! < 0) {
    return hold('unknown-subscribers', reset: true);
  }
  final fresh = freshScreenSignals(window, now, calibration);
  if (fresh.isEmpty) return hold('unknown-or-stale-signals', reset: true);
  final observed = fresh
      .where(
        (s) => s.pressure && sharedScreenBottlenecks.contains(s.bottleneck),
      )
      .map((s) => s.bottleneck)
      .toSet();
  if (observed.length > 1) return hold('mixed-bottlenecks', reset: true);
  final pressured = concordantScreenSignals(fresh, calibration, true);
  if (pressured.length == 1) {
    final kind = pressured.single;
    state.pressureWindows = state.pressureKind == kind
        ? state.pressureWindows + 1
        : 1;
    state.pressureKind = kind;
    state.healthySinceMs = null;
    if (state.pressureWindows < calibration.pressureWindows) {
      return hold('awaiting-confirmation');
    }
    return transitionScreenProfile(state, window, now, calibration, kind, true);
  }
  if (fresh.any((s) => s.receiverLocal && s.pressure)) {
    return hold('receiver-local-pressure', reset: true);
  }
  if (observed.isNotEmpty) return hold('bottleneck-unconfirmed', reset: true);
  final kind = state.pressureKind;
  if (kind == null) return hold('no-concordant-bottleneck', reset: true);
  final clear = fresh
      .where((s) => s.bottleneck == kind && !s.pressure && s.receiver == null)
      .map((s) => s.provenance)
      .toSet();
  if (clear.length < calibration.minIndependentSources ||
      fresh.any((s) => s.bottleneck == kind && s.pressure)) {
    return hold('recovery-unconfirmed', reset: true);
  }
  state.pressureWindows = 0;
  state.healthySinceMs ??= window.observedAtMs;
  if (window.observedAtMs - state.healthySinceMs! <
      calibration.recoveryDurationMs) {
    return hold('recovery-window');
  }
  return transitionScreenProfile(state, window, now, calibration, kind, false);
}
