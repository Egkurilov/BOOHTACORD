import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_diagnostics.dart';
import '../../../services/screen_share_metrics.dart';
import '../../../telemetry/report_media/sender_sample.dart';
import 'controller.dart';
import 'livekit_layers.dart';

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
      final List<rtc.StatsReport> reports =
          track.sender == null ? const [] : await track.sender!.getStats();
      final sources = screenSenderSourcesFromReports(reports);
      totalBitrateBps = track.currentBitrate;
      final layerSample = sampleLiveKitScreenLayers(
        layerSampler, sources, sampleClock.elapsedMilliseconds.toDouble(),
      );
      layerDiagnostics = layerSample.diagnostics.layers;
      final selected = layerSample.selected;
      if (previousLayerId != layerSample.diagnostics.selected?.id) previous = null;
      previousLayerId = layerSample.diagnostics.selected?.id;
      final current = selected == null ? null : screenShareSenderSnapshotFromStats([
        ScreenShareSenderStats(
          timestampMs: selected.counters.timestampMs,
          frameWidth: selected.counters.width,
          frameHeight: selected.counters.height,
          bytesSent: selected.counters.bytesSent,
          framesSent: selected.counters.framesSent,
          roundTripTimeSeconds: selected.roundTripTimeSeconds,
        ),
      ]);
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
      try {
        if (!reportCadence.isDue(sampleClock.elapsedMilliseconds.toDouble())) return;
        final samples = sources.where((item) => item.counters.id == layerSample.diagnostics.selected?.id)
            .map(
              (item) => SenderMediaSample(
                streamId: item.counters.id,
                timestamp: item.counters.timestampMs,
                frameWidth: item.width,
                frameHeight: item.height,
                packetsSent: item.counters.packetsSent,
                packetsLost: item.counters.packetsLost,
                qualityLimitationReason: item.counters.qualityLimitationReason,
              ),
            )
            .toList();
        await api.reportScreenShareMetrics({
          ...report.toJson(),
          ...telemetry.fields(
            samples,
            readQuality(),
            readRoom()?.localParticipant?.connectionQuality ??
                ConnectionQuality.unknown,
          ),
        });
      } catch (_) {
        // Diagnostic telemetry is best-effort and must not interrupt sharing.
      }
    } catch (error) {
      // Some platform WebRTC implementations do not expose sender stats.
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
