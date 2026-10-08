import '../profile/quality.dart';
import 'types.dart';

class ScreenAdaptationState {
  ScreenAdaptationState(this.current, this.ceiling, this.generation);
  ScreenAdaptationState.copy(ScreenAdaptationState value)
    : current = value.current,
      ceiling = value.ceiling,
      generation = value.generation,
      pressureKind = value.pressureKind,
      pressureWindows = value.pressureWindows,
      healthySinceMs = value.healthySinceMs,
      lastTransitionAtMs = value.lastTransitionAtMs,
      lastWindowId = value.lastWindowId,
      lastWindowAtMs = value.lastWindowAtMs,
      trendContent = value.trendContent,
      transitions = value.transitions;
  ScreenShareQuality current;
  final ScreenShareQuality ceiling;
  final int generation;
  ScreenBottleneck? pressureKind;
  int pressureWindows = 0, transitions = 0;
  double? healthySinceMs, lastTransitionAtMs, lastWindowAtMs;
  String? lastWindowId;
  ScreenAdaptationContent? trendContent;
  void resetTrend() {
    pressureWindows = 0;
    healthySinceMs = null;
  }
}

class ScreenAdaptationResult {
  const ScreenAdaptationResult(
    this.state,
    this.reason, {
    this.profile,
    this.kind,
  });
  final ScreenAdaptationState state;
  final String reason;
  final ScreenShareQuality? profile;
  final ScreenBottleneck? kind;
  bool get voiceFirst => profile != null;
}
