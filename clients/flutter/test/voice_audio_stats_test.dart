import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_diagnostics/stats.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_diagnostics/model.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_diagnostics/telemetry.dart';
List<Map<String, Object?>> report(int bytes, int packets, [int lost = 0]) => [
  {'id': 'codec', 'type': 'codec', 'mimeType': 'audio/opus', 'clockRate': 48000, 'channels': 2, 'sdpFmtpLine': 'useinbandfec=1;usedtx=1;stereo=0'},
  {'id': 'rtp', 'type': 'inbound-rtp', 'kind': 'audio', 'codecId': 'codec', 'bytesReceived': bytes, 'packetsReceived': packets, 'packetsLost': lost, 'jitter': 0.01, 'concealedSamples': lost * 480, 'concealmentEvents': lost, 'timestamp': bytes},
];
void main() {
  test('interval counters and codec channels match Web semantics', () {
    final reader = AudioStatsReader();
    expect(reader.read('track', 'receiver', report(100, 10), 0).single['bitrateBps'], isNull);
    final sample = reader.read('track', 'receiver', report(16100, 109, 1), 2000).single;
    expect(sample['bitrateBps'], 64000); expect(sample['lossPercent'], 1);
    expect(sample['jitterMs'], 10); expect(sample['concealedSamples'], 480);
    expect(sample['codecChannels'], 2); expect(sample['stereo'], isFalse);
    expect(sample['fec'], isTrue);
  });
  test('duplicate, replaced and rolled back sources do not reuse rates', () {
    final reader = AudioStatsReader()..read('track', 'receiver', report(100, 10), 0);
    expect(reader.read('track', 'receiver', report(100, 10), 2000).single['bitrateBps'], isNull);
    expect(reader.read('new', 'receiver', report(500, 30), 4000).single['bitrateBps'], isNull);
    expect(reader.read('track', 'receiver', report(50, 5), 4000).single['bitrateBps'], isNull);
    reader.retain({});
    expect(reader.read('track', 'receiver', report(500, 30), 6000).single['bitrateBps'], isNull);
    expect(reader.read('video', 'receiver', [{'type': 'inbound-rtp', 'kind': 'video'}], 6000), isEmpty);
  });
  test('safe export drops local levels and telemetry quantizes numbers', () {
    final sample = AudioStatsReader().read('track', 'receiver', report(100, 10), 0).single;
    sample['audioLevel'] = 0.123456; sample['bitrateBps'] = 65123;
    final snapshot = VoiceAudioDiagnostics('baseline-128-v1', 128000, {}, [sample]);
    expect(snapshot.toSafeJson().toString(), isNot(contains('audioLevel')));
    final attrs = audioTelemetryAttributes(snapshot.profile, sample, 'windows');
    expect(attrs['bitrate_kbps'], '64'); expect(attrs.toString(), isNot(contains('0.123456')));
  });
}
