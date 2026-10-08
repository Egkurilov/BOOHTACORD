import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_diagnostics.dart';
import '../../../services/screen_share_metrics.dart';
import 'controller.dart';
import 'livekit_layers.dart';
import 'report_measurements.dart';
import 'stats_poller.dart';
import 'report_sample.dart';

import 'dart:async';

import '../runtime_apply/options.dart';

extension ScreenShareSample on ScreenShareMetricsController {
  Future<void> sample(LocalVideoTrack track, int revision) async {
    final ticket = scope.capture();
    if (!ticket.isActive ||
        revision != gate.generation ||
        !identical(track, this.track) ||
        !isSharing() ||
        !gate.tryEnter(revision)) {
      return;
    }
    try {
      final observe = captureObservation?.call();
      final sender = track.sender;
      statsPoller = sender == null ? null : screenStatsPoller(sender);
      final List<rtc.StatsReport> reports = sender == null
          ? const []
          : await statsPoller!.read(sender.getStats);
      if (!ticket.isActive ||
          revision != gate.generation ||
          !identical(track, this.track) ||
          !isSharing()) {
        return;
      }
      final sources = screenSenderSourcesFromReports(reports);
      final layerSample = sampleLiveKitScreenLayers(
        layerSampler,
        sources,
        sampleClock.elapsedMilliseconds.toDouble(),
      );
      layerDiagnostics = layerSample.diagnostics.layers;
      final measurementFields = senderMeasurementFields(layerDiagnostics);
      final total = measurementFields['total_bitrate_kbps'];
      totalBitrateBps = total is num ? total * 1000 : null;
      final selected = layerSample.selected;
      if (previousLayerId != layerSample.diagnostics.selected?.id) {
        previous = null;
      }
      previousLayerId = layerSample.diagnostics.selected?.id;
      final current = senderSnapshot(selected);
      if (!ticket.isActive ||
          revision != gate.generation ||
          !identical(track, this.track) ||
          !isSharing()) {
        return;
      }
      final report = buildScreenShareSenderReport(
        previous: previous,
        current: current,
        platform: nativeScreenMetricsPlatform(defaultTargetPlatform)!,
      );
      logScreenShareDiagnostic(
        current == null
            ? ScreenShareDiagnosticEvent.senderStatsUnavailable
            : ScreenShareDiagnosticEvent.senderStatsSampled,
        platform: defaultTargetPlatform,
        senderStatsEntries: reports.length,
        framesSent: current?.framesSent?.round(),
        bytesSent: current?.bytesSent?.round(),
        encodedFramesPerSecond: report.encodedFps?.round(),
      );
      previous = current;
      this.report = report;
      sampledAt = DateTime.now();
      changed();
      unawaited(
        observe?.call(
          ScreenAdaptationObservation(
            report,
            List.unmodifiable(layerDiagnostics),
            sampleClock.elapsedMilliseconds.toDouble(),
          ),
        ),
      );
      await reportSample(report, sources, layerSample, measurementFields);
    } catch (error) {
      if (!ticket.isActive ||
          revision != gate.generation ||
          !identical(track, this.track)) {
        return;
      }
      // Some platform WebRTC implementations do not expose sender stats.
      report = null;
      sampledAt = null;
      changed();
      layerSampler.clear();
      layerDiagnostics = const [];
      previous = null;
      previousLayerId = null;
      totalBitrateBps = null;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.senderStatsUnavailable,
        platform: defaultTargetPlatform,
        errorType: error.runtimeType.toString(),
      );
    } finally {
      gate.leave(revision);
    }
  }
}
