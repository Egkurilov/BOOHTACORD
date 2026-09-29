import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/src/stats/stats.dart';

void main() {
  group('remoteRoundTripTimeForOutboundReport', () {
    test('reads RTT from the matched remote-inbound report', () {
      final reports = [
        rtc.StatsReport('outbound-1', 'outbound-rtp', 1, {
          'remoteId': 'remote-inbound-1',
          // RTT belongs to the paired remote-inbound report, not outbound RTP.
          'roundTripTime': 0,
        }),
        rtc.StatsReport('unrelated', 'remote-inbound-rtp', 1, {
          'roundTripTime': 0.8,
        }),
        rtc.StatsReport('remote-inbound-1', 'remote-inbound-rtp', 1, {
          'roundTripTime': 0.0424,
        }),
      ];

      expect(
        remoteRoundTripTimeForOutboundReport(
          reports,
          reports.first.values,
        ),
        0.0424,
      );
    });

    test('returns null without a matching remote-inbound report', () {
      final reports = [
        rtc.StatsReport('outbound-1', 'outbound-rtp', 1, {
          'roundTripTime': 0.0424,
        }),
        rtc.StatsReport('other', 'remote-inbound-rtp', 1, {
          'roundTripTime': 0.8,
        }),
      ];

      expect(
        remoteRoundTripTimeForOutboundReport(
          reports,
          reports.first.values,
        ),
        isNull,
      );
    });
  });
}
