import 'package:boohtacord_desktop/src/features/screen/metrics/livekit_layers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

void main() {
  test('keeps SSRC and pairs remote loss and RTT to the matching outbound', () {
    final reports = [
      rtc.StatsReport('codec', 'codec', 1000, {'mimeType': 'video/VP8'}),
      rtc.StatsReport('outbound-a', 'outbound-rtp', 1000, {
        'codecId': 'codec', 'ssrc': 101, 'rid': 'q', 'remoteId': 'remote-a',
        'packetsSent': 40, 'framesSent': 20,
      }),
      rtc.StatsReport('outbound-b', 'outbound-rtp', 1000, {
        'codecId': 'codec', 'ssrc': 202, 'rid': 'f', 'remoteId': 'remote-b',
        'packetsSent': 80, 'framesSent': 40,
      }),
      rtc.StatsReport('remote-a', 'remote-inbound-rtp', 1000, {
        'packetsLost': 3, 'roundTripTime': 0.04,
      }),
      rtc.StatsReport('remote-b', 'remote-inbound-rtp', 1000, {
        'packetsLost': 7, 'roundTripTime': 0.08,
      }),
    ];

    final sources = screenSenderSourcesFromReports(reports);

    expect(sources.map((source) => source.counters.ssrc), [101, 202]);
    expect(sources.map((source) => source.counters.packetsLost), [3, 7]);
    expect(sources.map((source) => source.roundTripTimeSeconds), [0.04, 0.08]);
    expect(sources.map((source) => source.counters.codec), ['video/VP8', 'video/VP8']);
  });
}
