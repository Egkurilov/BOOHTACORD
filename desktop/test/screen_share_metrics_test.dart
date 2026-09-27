import 'package:boohtacord_desktop/src/services/screen_share_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the highest-resolution sender layer and sums bytes', () {
    final snapshot = screenShareSenderSnapshotFromStats([
      const ScreenShareSenderStats(
        timestampMs: 1000,
        frameWidth: 640,
        frameHeight: 360,
        bytesSent: 1000,
        framesSent: 10,
        framesPerSecond: 12,
        roundTripTimeSeconds: 0.03,
      ),
      const ScreenShareSenderStats(
        timestampMs: 1000,
        frameWidth: 1920,
        frameHeight: 1080,
        bytesSent: 9000,
        framesSent: 20,
        framesPerSecond: 24,
        roundTripTimeSeconds: 0.05,
      ),
    ]);

    expect(snapshot?.bytesSent, 10000);
    expect(snapshot?.framesSent, 20);
    expect(snapshot?.framesPerSecond, 24);
    expect(snapshot?.roundTripTimeSeconds, 0.05);
  });

  test('reports only bounded Android sender measurements', () {
    const previous = ScreenShareSenderSnapshot(
      timestampMs: 1000,
      bytesSent: 100000,
      framesSent: 10,
    );
    const current = ScreenShareSenderSnapshot(
      timestampMs: 6000,
      bytesSent: 700000,
      framesSent: 100,
      roundTripTimeSeconds: 0.045,
    );

    final report = buildScreenShareSenderReport(
      previous: previous,
      current: current,
    );

    expect(report.toJson(), {
      'platform': 'android_native',
      'direction': 'sender',
      'state': 'playing',
      'encoded_fps': 18,
      'bitrate_kbps': 960,
      'rtt_ms': 45,
    });
  });

  test('does not invent rates before a baseline or after counter reset', () {
    const sample = ScreenShareSenderSnapshot(
      timestampMs: 5000,
      bytesSent: 400,
      framesSent: 12,
    );
    final initial = buildScreenShareSenderReport(
      previous: null,
      current: sample,
    );
    final reset = buildScreenShareSenderReport(
      previous: const ScreenShareSenderSnapshot(
        timestampMs: 1000,
        bytesSent: 800,
        framesSent: 30,
      ),
      current: sample,
    );

    expect(initial.toJson(), {
      'platform': 'android_native',
      'direction': 'sender',
      'state': 'waiting_first_frame',
    });
    expect(reset.encodedFps, isNull);
    expect(reset.bitrateKbps, isNull);
  });

  test('marks zero encoded FPS as stalled and clamps invalid metrics away', () {
    final report = buildScreenShareSenderReport(
      previous: null,
      current: const ScreenShareSenderSnapshot(
        timestampMs: 1000,
        bytesSent: double.infinity,
        framesPerSecond: 0,
        roundTripTimeSeconds: 100,
      ),
    );

    expect(report.toJson(), {
      'platform': 'android_native',
      'direction': 'sender',
      'state': 'stalled',
      'encoded_fps': 0,
    });
  });
}
