import 'package:boohtacord_desktop/src/features/screen/metrics/layers.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/report_measurements.dart';
import 'package:boohtacord_desktop/src/features/screen/receiver_metrics/read.dart';
import 'package:boohtacord_desktop/src/features/screen/receiver_metrics/compare.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

void main() {
  ScreenSenderLayerCounters row(String id, double at, int frames, int bytes) => ScreenSenderLayerCounters(streamId: id, rid: id,
    codec: 'video/VP8', timestampMs: at, width: id == 'f' ? 1920 : 640, height: 720, framesSent: frames,
    encodedFrames: frames, bytesSent: bytes, packetsSent: frames, packetsLost: 0, retransmittedPackets: 0, totalEncodeTime: frames * .002,
    retransmittedBytes: frames * 10, nackCount: frames);
  test('exports total bytes separately from selected layer with real intervals', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([row('f', 1000, 0, 0), row('q', 1000, 0, 0)], 1000);
    final measured = sampler.sample([row('f', 2000, 30, 100000), row('q', 2000, 30, 50000)], 2000);
    final fields = senderMeasurementFields(measured.layers);
    expect(fields, containsPair('total_bitrate_kbps', 1200.0));
    expect(fields, containsPair('selected_layer_bitrate_kbps', 800.0));
    expect(fields, containsPair('encode_ms_per_frame', 2.0));
    expect(fields, containsPair('stats_window_ms', 1000.0));
    expect(fields.keys, isNot(contains('ssrc')));
    expect(fields.keys, isNot(contains('rid')));
  });
  test('SDK receiver snapshots reject RTX-only and ambiguous video rows', () {
    final primary = rtc.StatsReport('video', 'inbound-rtp', 1000000, {'kind': 'video', 'ssrc': 2, 'framesDecoded': 10, 'totalDecodeTime': .1, 'jitterBufferDelay': 1, 'jitterBufferEmittedCount': 10});
    final next = rtc.StatsReport('video', 'inbound-rtp', 2000000, {'kind': 'video', 'ssrc': 2, 'framesDecoded': 30, 'totalDecodeTime': .14, 'jitterBufferDelay': 1.1, 'jitterBufferEmittedCount': 30, 'freezeCount': 2, 'totalFreezesDuration': .5});
    final rtx = rtc.StatsReport('rtx', 'inbound-rtp', 1000000, {'kind': 'video', 'bytesReceived': 50});
    final before = screenReceiverSnapshotFromReports([primary, rtx]);
    final metrics = compareScreenReceiverStats(before, screenReceiverSnapshotFromReports([next])!);
    expect(metrics.decodeMsPerFrame, closeTo(2, .0001));
    expect(metrics.jitterBufferMsPerFrame, closeTo(5, .0001));
    expect(metrics.freezeDurationMs, 500);
    expect(metrics.freezeCount, 2);
    expect(metrics.presentedFps, isNull);
    expect(screenReceiverSnapshotFromReports([rtx]), isNull);
    expect(screenReceiverSnapshotFromReports([primary, next]), isNull);
  });
}
