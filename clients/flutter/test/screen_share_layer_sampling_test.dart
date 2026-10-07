import 'package:boohtacord_desktop/src/features/screen/metrics/layers.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenSenderLayerCounters layer({
  String id = 'stream-full',
  String rid = 'f',
  int width = 1920,
  double timestamp = 1000,
  double frames = 0,
  double bytes = 0,
  double packets = 0,
  double lost = 0,
  double nacks = 0,
  int? ssrc = 1,
}) => ScreenSenderLayerCounters(
  streamId: id,
  ssrc: ssrc,
  rid: rid,
  codec: 'video/VP8',
  timestampMs: timestamp,
  width: width,
  height: width * 9 / 16,
  framesSent: frames,
  bytesSent: bytes,
  packetsSent: packets,
  packetsLost: lost,
  retransmittedPackets: 0,
  nackCount: nacks,
  pliCount: 0,
  firCount: 0,
);

void main() {
  test('keeps per RID rates separate and selects the higher progressing layer', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(), layer(id: 'stream-low', rid: 'q', width: 640)], 1000);
    final result = sampler.sample([
      layer(timestamp: 2000, frames: 30, bytes: 100000, packets: 100, lost: 2, nacks: 2),
      layer(id: 'stream-low', rid: 'q', width: 640, timestamp: 2000, frames: 15, bytes: 50000, packets: 50, lost: 1),
    ], 2000);
    expect(result.selected?.rid, 'f');
    expect(result.selected?.framesPerSecond, 30);
    expect(result.selected?.nackPerSecond, 2);
    expect(result.layers.map((item) => item.framesPerSecond), [30, 15]);
  });

  test('keeps first, reset and stale samples unavailable and rejects negative loss', () {
    final sampler = ScreenSenderLayerSampler();
    final first = sampler.sample([layer()], 1000);
    expect(first.selected, isNull);
    sampler.sample([layer(timestamp: 2000, frames: 30, bytes: 1000)], 2000);
    final reset = sampler.sample([layer(timestamp: 3000, frames: 1, bytes: 1)], 3000);
    expect(reset.selected, isNull);
    final stale = sampler.sample([layer(timestamp: 4000, frames: 31, bytes: 2000, packets: 10, lost: -1)], 20000);
    expect(stale.layers.single.state, 'STALE');
    expect(stale.layers.single.packetLossPercent, isNull);
  });

  test('starts a new counter window when SSRC changes', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(frames: 10, bytes: 100)], 1000);
    final changed = sampler.sample([
      layer(timestamp: 2000, frames: 40, bytes: 1100, ssrc: 2),
    ], 2000);
    expect(changed.selected, isNull);
    final next = sampler.sample([
      layer(timestamp: 3000, frames: 70, bytes: 2100, ssrc: 2),
    ], 3000);
    expect(next.selected?.framesPerSecond, 30);
  });

  test('does not select a frozen high layer because bytes continue to grow', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([
      layer(frames: 10, bytes: 100),
      layer(id: 'low', rid: 'q', width: 640, frames: 10, bytes: 100),
    ], 1000);
    final result = sampler.sample([
      layer(timestamp: 2000, frames: 10, bytes: 1100),
      layer(id: 'low', rid: 'q', width: 640, timestamp: 2000, frames: 40, bytes: 1100),
    ], 2000);
    expect(result.layers.first.state, 'INACTIVE');
    expect(result.selected?.rid, 'q');
  });

  test('signed loss correction does not reset frame and byte progress', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(lost: 4)], 1000);
    final next = sampler.sample([layer(timestamp: 2000, frames: 30, bytes: 1000, packets: 10, lost: 2)], 2000);
    expect(next.selected?.framesPerSecond, 30);
    expect(next.selected?.packetLossPercent, isNull);
  });

  test('invalidates all rates for an interval with a counter reset', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(frames: 10, bytes: 1000, packets: 20)], 1000);
    final reset = sampler.sample([
      layer(timestamp: 2000, frames: 40, bytes: 2000, packets: 2),
    ], 2000);
    expect(reset.layers.single.state, 'UNKNOWN');
    expect(reset.layers.single.framesPerSecond, isNull);
    expect(reset.layers.single.bitrateBps, isNull);
  });
}
