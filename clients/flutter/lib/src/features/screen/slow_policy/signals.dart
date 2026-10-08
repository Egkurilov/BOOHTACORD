import 'types.dart';
import 'calibration.dart';

List<ScreenAdaptationSignal> freshScreenSignals(
  ScreenAdaptationWindow window,
  double now,
  ScreenAdaptationCalibration calibration,
) => window.signals
    .where(
      (signal) =>
          signal.generation == window.generation &&
          signal.observedAtMs.isFinite &&
          signal.observedAtMs <= window.observedAtMs &&
          signal.observedAtMs <= now &&
          now - signal.observedAtMs <= calibration.maxSignalAgeMs &&
          (!signal.receiverLocal || signal.receiver?.isNotEmpty == true),
    )
    .toList();
List<ScreenBottleneck> concordantScreenSignals(
  List<ScreenAdaptationSignal> signals,
  ScreenAdaptationCalibration calibration,
  bool pressure,
) => sharedScreenBottlenecks
    .where(
      (kind) =>
          signals
              .where(
                (signal) =>
                    signal.bottleneck == kind &&
                    signal.pressure == pressure &&
                    signal.receiver == null,
              )
              .map((signal) => signal.provenance)
              .toSet()
              .length >=
          calibration.minIndependentSources,
    )
    .toList();
