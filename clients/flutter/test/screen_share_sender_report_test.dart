import 'package:boohtacord_desktop/src/services/screen_share_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports bounded sender measurements from counter deltas', () {
    const previous = ScreenShareSenderSnapshot(
      timestampMs: 1000, bytesSent: 100000, framesSent: 10);
    const current = ScreenShareSenderSnapshot(
      timestampMs: 6000, frameWidth: 540, frameHeight: 1170,
      bytesSent: 700000, framesSent: 100, roundTripTimeSeconds: 0.045);
    final report = buildScreenShareSenderReport(
      previous: previous, current: current);
    expect(report.toJson(), {
      'platform': 'android_native', 'direction': 'sender', 'state': 'playing',
      'frame_width': 540, 'frame_height': 1170, 'encoded_fps': 18,
      'bitrate_kbps': 960, 'rtt_ms': 45,
    });
  });

  test('reports desktop sender measurements with desktop platform', () {
    final report = buildScreenShareSenderReport(
      previous: const ScreenShareSenderSnapshot(timestampMs: 0, framesSent: 0),
      current: const ScreenShareSenderSnapshot(timestampMs: 1000, framesSent: 30,
        frameWidth: 1920, frameHeight: 1080, framesPerSecond: 30),
      platform: 'desktop_native',
    );
    expect(report.toJson(), {
      'platform': 'desktop_native', 'direction': 'sender', 'state': 'playing',
      'frame_width': 1920, 'frame_height': 1080, 'encoded_fps': 30,
    });
  });

  test('omits incomplete dimensions and rates without an interval', () {
    final snapshot = screenShareSenderSnapshotFromStats([
      const ScreenShareSenderStats(timestampMs: 1000, frameWidth: 540),
    ]);
    expect(snapshot?.frameWidth, isNull);
    expect(snapshot?.frameHeight, isNull);
    expect(buildScreenShareSenderReport(previous: null, current: snapshot).toJson(), {
      'platform': 'android_native', 'direction': 'sender',
      'state': 'waiting_first_frame',
    });
  });

  test('does not invent rates before a baseline or after counter reset', () {
    const sample = ScreenShareSenderSnapshot(
      timestampMs: 5000, bytesSent: 400, framesSent: 12);
    final initial = buildScreenShareSenderReport(previous: null, current: sample);
    final reset = buildScreenShareSenderReport(
      previous: const ScreenShareSenderSnapshot(
        timestampMs: 1000, bytesSent: 800, framesSent: 30),
      current: sample,
    );
    expect(initial.state, 'waiting_first_frame');
    expect(reset.encodedFps, isNull);
    expect(reset.bitrateKbps, isNull);
  });

  test('does not publish SDK instantaneous FPS without a valid interval', () {
    final report = buildScreenShareSenderReport(
      previous: null,
      current: const ScreenShareSenderSnapshot(
        timestampMs: 5000, framesSent: 20, framesPerSecond: 30),
    );
    expect(report.encodedFps, isNull);
    expect(report.state, 'waiting_first_frame');
  });
}
