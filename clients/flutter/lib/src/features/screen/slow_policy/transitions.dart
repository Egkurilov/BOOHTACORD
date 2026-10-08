import 'types.dart';
import 'state.dart';
import 'calibration.dart';

ScreenAdaptationResult transitionScreenProfile(
  ScreenAdaptationState state,
  ScreenAdaptationWindow window,
  double now,
  ScreenAdaptationCalibration calibration,
  ScreenBottleneck kind,
  bool down,
) {
  if (state.transitions >= calibration.maxTransitions ||
      state.lastTransitionAtMs != null &&
          now - state.lastTransitionAtMs! < calibration.minimumDwellMs) {
    if (down) state.resetTrend();
    return ScreenAdaptationResult(
      state,
      state.transitions >= calibration.maxTransitions
          ? 'transition-limit'
          : 'cooldown',
      kind: kind,
    );
  }
  final target = calibration.step(
    kind,
    window.content,
    state.current,
    state.ceiling,
    down,
  );
  if (target == null) {
    if (down) state.resetTrend();
    return ScreenAdaptationResult(
      state,
      down ? 'profile-floor-or-ceiling' : 'user-ceiling',
      kind: kind,
    );
  }
  state.current = target;
  state.lastTransitionAtMs = window.observedAtMs;
  state.transitions++;
  state.resetTrend();
  return ScreenAdaptationResult(
    state,
    down ? 'downgrade-pressure' : 'recovered',
    profile: target,
    kind: kind,
  );
}
