import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_diagnostics/stats.dart';
List<Map<String, Object?>> reports(int bytes, int packets, int timestamp,
    [Map<String, Object?> extra = const {}]) => [{
  'id': 'rtp', 'type': 'inbound-rtp', 'kind': 'audio', 'ssrc': 1,
  'codecId': 'opus', 'bytesReceived': bytes, 'packetsReceived': packets,
  'packetsLost': 1, 'concealedSamples': 480, 'concealmentEvents': 1,
  'timestamp': timestamp, ...extra,
}];
void main() {
  for (final field in ['ssrc', 'codecId', 'mediaSourceId', 'mid', 'transportId']) {
    test('$field change rebaselines a reused report id', () {
      final reader = AudioStatsReader()..read('mic', 'receiver', reports(1000, 10, 1), 0);
      final extra = <String, Object?>{field: field == 'ssrc' ? 2 : 'new-opus'};
      final replaced = reader.read('mic', 'receiver', reports(17000, 30, 2, extra), 2000).single;
      for (final key in ['bitrateBps', 'packets', 'intervalMs', 'concealedSamples']) {
        expect(replaced[key], isNull);
      }
      expect(reader.read('mic', 'receiver', reports(33000, 50, 3, extra), 4000).single['bitrateBps'], 64000);
    });
  }
  for (final field in ['bytesReceived', 'packetsReceived']) {
    test('$field rollback invalidates all interval fields and recovers', () {
      final reader = AudioStatsReader()..read('mic', 'receiver', reports(1000, 10, 1), 0);
      final reset = reader.read('mic', 'receiver', reports(1500, 20, 2, {field: 1}), 2000).single;
      for (final key in ['intervalMs', 'bitrateBps', 'packets', 'lossPercent', 'concealedSamples', 'concealmentEvents']) {
        expect(reset[key], isNull);
      }
      final nextBytes = field == 'bytesReceived' ? 16001 : 17500;
      expect(reader.read('mic', 'receiver', reports(nextBytes, 40, 3), 4000).single['bitrateBps'], 64000);
    });
  }
  test('stale timestamp cannot rewind a valid baseline', () {
    final reader = AudioStatsReader()..read('mic', 'receiver', reports(100, 10, 10), 0);
    expect(reader.read('mic', 'receiver', reports(500, 20, 9), 2000).single['bitrateBps'], isNull);
    expect(reader.read('mic', 'receiver', reports(1100, 30, 11), 4000).single['bitrateBps'], 2000);
  });
}
