import 'dart:async';

import '../slow_policy/types.dart';
import '../slow_policy/calibration.dart';
import '../metrics/models.dart';
import '../metrics/sender_report.dart';
import 'port.dart';

class ScreenAdaptationObservation {
  const ScreenAdaptationObservation(
    this.report,
    this.layers,
    this.observedAtMs,
  );
  final ScreenShareSenderReport report;
  final List<ScreenSenderLayerMetrics> layers;
  final double observedAtMs;
}

class ScreenAdaptationOptions {
  const ScreenAdaptationOptions({
    this.enabled = false,
    this.calibration,
    this.readWindow,
    this.now,
  });
  ScreenAdaptationOptions snapshot() => ScreenAdaptationOptions(
    enabled: enabled,
    calibration: calibration?.snapshot(),
    readWindow: readWindow,
    now: now,
  );
  final bool enabled;
  final ScreenAdaptationCalibration? calibration;
  final FutureOr<ScreenAdaptationWindow?> Function(
    ScreenAdaptationObservation,
    ScreenRuntimeBinding,
  )?
  readWindow;
  final double Function()? now;
  bool get admitted => enabled && calibration?.valid == true;
}
