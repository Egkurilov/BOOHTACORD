import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_metrics.dart';
import '../../../telemetry/report_media/sender_sample.dart';
import 'controller.dart';

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
      final stats = await track.getSenderStats();
      final current = screenShareSenderSnapshotFromStats(
        stats
            .map(
              (item) => ScreenShareSenderStats(
                timestampMs: webRtcStatsTimestampMs(item.timestamp),
                frameWidth: item.frameWidth,
                frameHeight: item.frameHeight,
                bytesSent: item.bytesSent,
                framesSent: item.framesSent,
                framesPerSecond: item.framesPerSecond,
                roundTripTimeSeconds: item.roundTripTime,
              ),
            )
            .toList(growable: false),
      );
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
      previous = current;
      try {
        final samples = stats
            .map(
              (item) => SenderMediaSample(
                streamId: item.streamId,
                timestamp: webRtcStatsTimestampMs(item.timestamp),
                frameWidth: item.frameWidth,
                frameHeight: item.frameHeight,
                packetsSent: item.packetsSent,
                packetsLost: item.packetsLost,
                qualityLimitationReason: item.qualityLimitationReason,
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
    } catch (_) {
      // Some platform WebRTC implementations do not expose sender stats.
    } finally {
      gate.leave(revision);
    }
  }
}
