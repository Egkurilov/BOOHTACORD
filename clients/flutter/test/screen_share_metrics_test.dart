import 'package:boohtacord_desktop/src/services/screen_share_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts WebRTC microsecond timestamps to milliseconds', () {
    expect(webRtcStatsTimestampMs(5000000), 5000);
    expect(webRtcStatsTimestampMs(10000000), 10000);
  });

  test('maps supported native clients to server telemetry platforms', () {
    expect(nativeScreenMetricsPlatform(TargetPlatform.android), 'android_native');
    expect(nativeScreenMetricsPlatform(TargetPlatform.macOS), 'macos_native');
    expect(nativeScreenMetricsPlatform(TargetPlatform.windows), 'windows_native');
    expect(nativeScreenMetricsPlatform(TargetPlatform.iOS), 'ios_native');
  });

  test('selects the highest-resolution sender layer and sums bytes', () {
    final snapshot = screenShareSenderSnapshotFromStats([
      const ScreenShareSenderStats(timestampMs: 1000, frameWidth: 640,
        frameHeight: 360, bytesSent: 1000, framesSent: 10,
        framesPerSecond: 12, roundTripTimeSeconds: 0.03),
      const ScreenShareSenderStats(timestampMs: 1000, frameWidth: 1920,
        frameHeight: 1080, bytesSent: 9000, framesSent: 20,
        framesPerSecond: 24, roundTripTimeSeconds: 0.05),
    ]);
    expect(snapshot?.bytesSent, 10000);
    expect(snapshot?.frameWidth, 1920);
    expect(snapshot?.frameHeight, 1080);
    expect(snapshot?.framesSent, 20);
    expect(snapshot?.framesPerSecond, 24);
    expect(snapshot?.roundTripTimeSeconds, 0.05);
  });
}
