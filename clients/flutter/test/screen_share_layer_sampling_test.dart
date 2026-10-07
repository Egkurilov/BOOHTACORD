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
}) => ScreenSenderLayerCounters(
  streamId: id,
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
  test('keeps per RID rates separate and ignores a frozen higher layer', () {
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
}
