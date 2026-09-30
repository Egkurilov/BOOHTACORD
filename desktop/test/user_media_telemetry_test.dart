import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/telemetry/report_media/sender_sample.dart';
import 'package:boohtacord_desktop/src/telemetry/report_media/sender.dart';
import 'package:boohtacord_desktop/src/telemetry/report_media/connection.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';

void main() {
  test('sender reports ten-second loss independently of lifetime totals', () {
    final telemetry = SenderMediaTelemetry();
    Map<String, Object> sample(int time, int sent, int lost) =>
        telemetry.fields(
          [
            SenderMediaSample(
              streamId: 'stream-a',
              timestamp: time,
              frameWidth: 1280,
              frameHeight: 720,
              packetsSent: sent,
              packetsLost: lost,
              qualityLimitationReason: 'bandwidth',
            ),
          ],
          const ScreenShareQuality(resolution: 1440, frameRate: 60),
          ConnectionQuality.good,
        );
    expect(sample(0, 10000, 2476), isNot(contains('packet_loss_percent')));
    expect(
      sample(10000, 11000, 2486),
      containsPair('packet_loss_percent', 1.0),
    );
    final fields = sample(20000, 12000, 2486);
    expect(fields, containsPair('packet_loss_percent', 0.0));
    expect(fields, containsPair('packet_loss_window_ms', 10000.0));
    expect(fields, containsPair('target_resolution', 1440));
    expect(fields, containsPair('target_fps', 60));
    expect(fields, containsPair('connection_quality', 'GOOD'));
    telemetry.clear();
    expect(sample(30000, 13000, 2500), isNot(contains('packet_loss_percent')));
  });
  test(
    'connection reporting preserves missing RTT and throttles failures',
    () async {
      final reports = <Map<String, Object>>[];
      var now = DateTime(2026);
      final reporter = ConnectionMediaReporter(
        (report) async {
          reports.add(report);
        },
        'ios_native',
        now: () => now,
      );
      await reporter.submit(null, ConnectionQuality.poor);
      await reporter.submit(99, ConnectionQuality.good);
      expect(reports, hasLength(1));
      expect(reports.single, isNot(contains('rtt_ms')));
      now = now.add(const Duration(seconds: 5));
      await reporter.submit(12, ConnectionQuality.good);
      expect(reports.last, containsPair('rtt_ms', 12));
      expect(reports.last, containsPair('direction', 'connection'));
    },
  );
}
