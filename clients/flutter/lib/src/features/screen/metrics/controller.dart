import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import '../../../services/screen_share_quality.dart';
import '../../../services/screen_share_metrics.dart';
import '../../../services/screen_share_metrics_generation_gate.dart';
import '../../../telemetry/report_media/sender.dart';
import 'sample.dart';

class ScreenShareMetricsController {
  ScreenShareMetricsController(
    this.api,
    this.scope, {
    required this.readRoom,
    required this.isSharing,
    required this.readQuality,
    required this.changed,
  });
  final void Function() changed;
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
  final gate = ScreenShareMetricsGenerationGate();
  final telemetry = SenderMediaTelemetry();
  void start(LocalVideoTrack track) {
    stop();
    final revision = gate.generation;
    this.track = track;
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(sample(track, revision));
    });
    unawaited(sample(track, revision));
  }

  void stop() {
    gate.nextGeneration();
    timer?.cancel();
    timer = null;
    track = null;
    previous = null;
    report = null;
    sampledAt = null;
    telemetry.clear();
  }
}
