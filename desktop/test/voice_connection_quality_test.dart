import 'package:boohtacord_desktop/src/services/voice_connection_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' show ConnectionQuality;

void main() {
  test('maps LiveKit quality to concise localized labels', () {
    expect(
      voiceConnectionQualityLabel(ConnectionQuality.excellent),
      'Отличное',
    );
    expect(voiceConnectionQualityLabel(ConnectionQuality.good), 'Хорошее');
    expect(voiceConnectionQualityLabel(ConnectionQuality.poor), 'Низкое');
    expect(voiceConnectionQualityLabel(ConnectionQuality.lost), 'Потеряно');
    expect(
      voiceConnectionQualityLabel(ConnectionQuality.unknown),
      'Нет данных',
    );
  });

  test('converts only finite bounded RTT seconds to milliseconds', () {
    expect(voiceRttMilliseconds(0.0424), 42);
    expect(voiceRttMilliseconds(0), 0);
    expect(voiceRttMilliseconds(null), isNull);
    expect(voiceRttMilliseconds(-0.1), isNull);
    expect(voiceRttMilliseconds(double.nan), isNull);
    expect(voiceRttMilliseconds(61), isNull);
  });

  test('retains the latest ping when a connected stats sample has no RTT', () {
    expect(
      voicePingAfterMeasurement(
        previousPingMilliseconds: 42,
        measuredPingMilliseconds: null,
      ),
      42,
    );
    expect(
      voicePingAfterMeasurement(
        previousPingMilliseconds: 42,
        measuredPingMilliseconds: 67,
      ),
      67,
    );
    expect(
      voicePingAfterMeasurement(
        previousPingMilliseconds: null,
        measuredPingMilliseconds: null,
      ),
      isNull,
    );
  });

  test('uses selected ICE-pair RTT when microphone feedback is absent', () {
    final reports = [
      rtc.StatsReport('transport-1', 'transport', 1, {
        'selectedCandidatePairId': 'pair-selected',
      }),
      rtc.StatsReport('pair-old', 'candidate-pair', 1, {
        'state': 'succeeded',
        'nominated': true,
        'currentRoundTripTime': 0.9,
      }),
      rtc.StatsReport('pair-selected', 'candidate-pair', 1, {
        'state': 'succeeded',
        'nominated': true,
        'currentRoundTripTime': 0.067,
      }),
    ];

    expect(voiceRttMillisecondsFromReports(reports), 67);
  });

  test('reads selected ICE-pair RTT from subscriber connection', () {
    final subscriberReports = [
      rtc.StatsReport('transport-sub', 'transport', 1, {
        'selectedCandidatePairId': 'pair-sub',
      }),
      rtc.StatsReport('pair-sub', 'candidate-pair', 1, {
        'state': 'succeeded',
        'nominated': true,
        'currentRoundTripTime': 0.083,
      }),
    ];

    expect(
      voiceRttMillisecondsFromPeerConnections([const [], subscriberReports]),
      83,
    );
  });

  test('prefers audio RTT across peer connections over ICE RTT', () {
    final publisherReports = [
      rtc.StatsReport('audio-remote', 'remote-inbound-rtp', 1, {
        'kind': 'audio',
        'roundTripTime': 0.041,
      }),
    ];
    final subscriberReports = [
      rtc.StatsReport('transport-sub', 'transport', 1, {
        'selectedCandidatePairId': 'pair-sub',
      }),
      rtc.StatsReport('pair-sub', 'candidate-pair', 1, {
        'state': 'succeeded',
        'nominated': true,
        'currentRoundTripTime': 0.083,
      }),
    ];

    expect(
      voiceRttMillisecondsFromPeerConnections([
        publisherReports,
        subscriberReports,
      ]),
      41,
    );
  });

  test('prefers audio remote-inbound RTT and ignores stale ICE pairs', () {
    final reports = [
      rtc.StatsReport('transport-1', 'transport', 1, {
        'selectedCandidatePairId': 'pair-selected',
      }),
      rtc.StatsReport('pair-selected', 'candidate-pair', 1, {
        'state': 'succeeded',
        'nominated': true,
        'currentRoundTripTime': 0.067,
      }),
      rtc.StatsReport('audio-remote', 'remote-inbound-rtp', 1, {
        'kind': 'audio',
        'roundTripTime': 0.041,
      }),
    ];

    expect(voiceRttMillisecondsFromReports(reports), 41);
  });

  test('does not treat an unselected ICE candidate pair as ping', () {
    final reports = [
      rtc.StatsReport('pair-old', 'candidate-pair', 1, {
        'state': 'succeeded',
        'nominated': false,
        'currentRoundTripTime': 0.067,
      }),
    ];

    expect(voiceRttMillisecondsFromReports(reports), isNull);
  });
}
