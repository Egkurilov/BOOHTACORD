import 'package:livekit_client/livekit_client.dart' show ConnectionQuality;
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

String voiceConnectionQualityLabel(ConnectionQuality quality) =>
    switch (quality) {
      ConnectionQuality.excellent => 'Отличное',
      ConnectionQuality.good => 'Хорошее',
      ConnectionQuality.poor => 'Низкое',
      ConnectionQuality.lost => 'Потеряно',
      ConnectionQuality.unknown => 'Нет данных',
    };

int? voiceRttMilliseconds(num? seconds) {
  if (seconds == null || !seconds.isFinite || seconds < 0 || seconds > 60) {
    return null;
  }
  return (seconds * 1000).round();
}

int? voiceRttMillisecondsFromReports(Iterable<rtc.StatsReport> reports) {
  final items = reports.toList(growable: false);
  final inboundAudio = items.where(
    (report) =>
        report.type == 'remote-inbound-rtp' &&
        (report.values['kind'] ?? report.values['mediaType']) == 'audio',
  );
  for (final report in inboundAudio) {
    final rtt = voiceRttMilliseconds(
      _statNumber(report.values['roundTripTime']),
    );
    if (rtt != null) return rtt;
  }
  for (final report in items.where(
    (report) => report.type == 'remote-inbound-rtp',
  )) {
    final rtt = voiceRttMilliseconds(
      _statNumber(report.values['roundTripTime']),
    );
    if (rtt != null) return rtt;
  }

  final selectedPairIds = items
      .where((report) => report.type == 'transport')
      .map((report) => report.values['selectedCandidatePairId'])
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();
  if (selectedPairIds.isNotEmpty) {
    for (final report in items.where(
      (report) =>
          report.type == 'candidate-pair' &&
          selectedPairIds.contains(report.id),
    )) {
      final rtt = voiceRttMilliseconds(
        _statNumber(report.values['currentRoundTripTime']),
      );
      if (rtt != null) return rtt;
    }
    return null;
  }

  final candidatePairs = items.where(
    (report) => report.type == 'candidate-pair',
  );
  final explicitlySelected = candidatePairs.where(
    (report) => report.values['selected'] == true,
  );
  for (final report in explicitlySelected) {
    final rtt = voiceRttMilliseconds(
      _statNumber(report.values['currentRoundTripTime']),
    );
    if (rtt != null) return rtt;
  }
  for (final report in candidatePairs.where(
    (report) =>
        report.values['state'] == 'succeeded' &&
        report.values['nominated'] == true,
  )) {
    final rtt = voiceRttMilliseconds(
      _statNumber(report.values['currentRoundTripTime']),
    );
    if (rtt != null) return rtt;
  }
  return null;
}

num? _statNumber(Object? value) => switch (value) {
  final num number => number,
  final String text => num.tryParse(text),
  _ => null,
};
