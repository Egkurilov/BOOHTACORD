import 'package:livekit_client/livekit_client.dart';

import '../../../telemetry/report_media/sender_sample.dart';
import 'controller.dart';
import 'livekit_layers.dart';
import '../../../services/screen_share_metrics.dart';

extension ScreenReportSample on ScreenShareMetricsController {
  Future<void> reportSample(
    ScreenShareSenderReport report,
    List<ScreenSenderLayerSource> sources,
    LiveKitScreenLayerSample layerSample,
    Map<String, Object> measurementFields,
  ) async {
    try {
      if (!reportCadence.isDue(sampleClock.elapsedMilliseconds.toDouble())) {
        return;
      }
      final samples = sources
          .where(
            (item) => item.counters.id == layerSample.diagnostics.selected?.id,
          )
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
        ...measurementFields,
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
  }
}

ScreenShareSenderSnapshot? senderSnapshot(ScreenSenderLayerSource? selected) =>
    selected == null
    ? null
    : screenShareSenderSnapshotFromStats([
        ScreenShareSenderStats(
          timestampMs: selected.counters.timestampMs,
          frameWidth: selected.counters.width,
          frameHeight: selected.counters.height,
          bytesSent: selected.counters.bytesSent,
          framesSent: selected.counters.encodedFrames,
          roundTripTimeSeconds: selected.roundTripTimeSeconds,
        ),
      ]);
