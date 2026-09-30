import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:boohtacord_desktop/src/services/screen_receiver_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports interval loss, preserves zero, and drops old samples', () {
    Map<String, Object>? report(int age) => buildScreenReceiverReport(
      platform: 'ios_native',
      selected: true,
      hasTrack: true,
      current: null,
      metrics: const ScreenReceiverMetrics(packetLossPercent: 0),
      packetLossWindowMs: 10000,
      sampleAgeMs: age,
    );
    expect(report(1000), containsPair('packet_loss_percent', 0.0));
    expect(report(1000), containsPair('packet_loss_window_ms', 10000.0));
    expect(report(16000), isNull);
  });
  test('builds a bounded report for the selected desktop receiver', () {
    final report = buildScreenReceiverReport(
      platform: 'desktop_native',
      selected: true,
      hasTrack: true,
      current: const ScreenReceiverSnapshot(
        timestampMs: 6000,
        bytesReceived: 100000,
        framesDecoded: 160,
        framesRendered: 140,
        framesDropped: 4,
        jitterSeconds: 0.012,
        packetsLost: 3,
        frameWidth: 1920,
        frameHeight: 1080,
        framesPerSecond: 30,
      ),
      metrics: const ScreenReceiverMetrics(
        bitrateKbps: 800,
        decodedFps: 24,
        presentedFps: 20,
        droppedFrames: 2,
        jitterMs: 12,
        packetsLost: 3,
      ),
    );

    expect(report, {
      'platform': 'desktop_native',
      'direction': 'receiver',
      'state': 'playing',
      'frame_width': 1920,
      'frame_height': 1080,
      'decoded_fps': 24,
      'presented_fps': 20,
      'bitrate_kbps': 800,
      'jitter_ms': 12,
      'packets_lost': 3,
      'dropped_frames': 2,
    });
  });

  test('reports a selected stream that is still waiting for subscription', () {
    expect(
      buildScreenReceiverReport(
        platform: 'android_native',
        selected: true,
        hasTrack: false,
        current: null,
        metrics: null,
      ),
      {
        'platform': 'android_native',
        'direction': 'receiver',
        'state': 'waiting_subscription',
      },
    );
  });

  test('does not report an unselected or local preview stream', () {
    expect(
      buildScreenReceiverReport(
        platform: 'desktop_native',
        selected: false,
        hasTrack: true,
        current: null,
        metrics: null,
      ),
      isNull,
    );
  });
}
