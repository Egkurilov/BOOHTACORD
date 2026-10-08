import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import '../profile/quality.dart';
import '../../../services/screen_share_metrics.dart';
import '../../../services/screen_share_metrics_generation_gate.dart';
import '../../../telemetry/report_media/sender.dart';
import 'layers.dart';
import '../runtime_apply/options.dart';
import 'report_cadence.dart';
import 'sample.dart';
import 'stats_poller.dart';

class ScreenShareMetricsController {
  ScreenShareMetricsController(
    this.api,
    this.scope, {
    required this.readRoom,
    required this.isSharing,
    required this.readQuality,
    required this.changed,
    this.captureObservation,
  });
  final void Function() changed;
  final Future<void> Function(ScreenAdaptationObservation)? Function()?
  captureObservation;
  ScreenShareSenderReport? report;
  DateTime? sampledAt;
  final ApiClient api;
  final SessionScope scope;
  final Room? Function() readRoom;
  final bool Function() isSharing;
  final ScreenShareQuality Function() readQuality;
  Timer? timer;
  LocalVideoTrack? track;
  ScreenShareSenderSnapshot? previous;
  String? previousLayerId;
  num? totalBitrateBps;
  List<ScreenSenderLayerMetrics> layerDiagnostics = const [];
  ScreenStatsPoller? statsPoller;
  final layerSampler = ScreenSenderLayerSampler();
  final gate = ScreenShareMetricsGenerationGate();
  final telemetry = SenderMediaTelemetry();
  final sampleClock = Stopwatch()..start();
  final reportCadence = ScreenShareReportCadence();
  void start(LocalVideoTrack track) {
    stop();
    final revision = gate.generation;
    this.track = track;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(sample(track, revision));
    });
    unawaited(sample(track, revision));
  }

  void stop() {
    gate.nextGeneration();
    timer?.cancel();
    timer = null;
    statsPoller?.clear();
    statsPoller = null;
    track = null;
    previous = null;
    previousLayerId = null;
    totalBitrateBps = null;
    layerDiagnostics = const [];
    layerSampler.clear();
    sampleClock.reset();
    reportCadence.clear();
    report = null;
    sampledAt = null;
    telemetry.clear();
  }
}
