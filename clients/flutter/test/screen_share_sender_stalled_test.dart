import 'package:boohtacord_desktop/src/services/screen_share_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks zero encoded FPS stalled and clamps invalid metrics', () {
    final report = buildScreenShareSenderReport(
      previous: const ScreenShareSenderSnapshot(
        timestampMs: 0, framesSent: 20, bytesSent: 0),
      current: const ScreenShareSenderSnapshot(
        timestampMs: 1000, framesSent: 20, bytesSent: double.infinity,
        framesPerSecond: 0, roundTripTimeSeconds: 100),
    );
    expect(report.toJson(), {
      'platform': 'android_native', 'direction': 'sender',
      'state': 'stalled', 'encoded_fps': 0,
    });
  });
}
