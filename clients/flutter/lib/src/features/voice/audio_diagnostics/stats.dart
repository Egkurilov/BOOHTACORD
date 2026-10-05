import 'codec.dart';
import 'model.dart';
import 'interval.dart';
class AudioStatsReader {
  final _previous = <String, ({double at, Map<String, Object?> report})>{};
  void retain(Set<String> scopes) => _previous.removeWhere((key, _) => !scopes.contains(key.split('\n').first));
  List<Map<String, Object?>> read(String scope, String direction, List<Map<String, Object?>> reports, double at) {
    final type = direction == 'sender' ? 'outbound-rtp' : 'inbound-rtp';
    final activeKeys = reports.where((rtp) => rtp['type'] == type).map((rtp) => '$scope\n${rtp['id']}').toSet();
    _previous.removeWhere((key, _) => key.startsWith('$scope\n') && !activeKeys.contains(key));
    return reports.where((rtp) => rtp['type'] == type && (rtp['kind'] ?? rtp['mediaType'] ?? 'audio') == 'audio' && rtp['isRemote'] != true).map((rtp) {
      final key = '$scope\n${rtp['id']}';
      final old = _previous[key];
      final dt = old == null ? 0.0 : at - old.at;
      final (:fresh, :valid) = audioInterval(rtp, old?.report, at, old?.at, direction);
      double? delta(String field) {
        final current = statNumber(rtp[field]), previous = statNumber(old?.report[field]);
        return valid && current != null && previous != null && current >= previous ? current - previous : null;
      }
      final bytes = delta(direction == 'sender' ? 'bytesSent' : 'bytesReceived');
      final packets = delta(direction == 'sender' ? 'packetsSent' : 'packetsReceived');
      final lost = delta('packetsLost'), jitter = statNumber(rtp['jitter']);
      if (fresh) _previous[key] = (at: at, report: {...rtp});
      Map<String, Object?>? source;
      for (final report in reports) { if (report['id'] == rtp['mediaSourceId']) source = report; }
      final level = statNumber(rtp['audioLevel']) ?? statNumber(source?['audioLevel']);
      return <String, Object?>{
        'direction': direction, ...audioCodec(rtp, reports),
        'bitrateBps': bytes == null ? null : bytes * 8000 / dt,
        'intervalMs': valid ? dt : null,
        'packets': packets, 'jitterMs': jitter == null ? null : jitter * 1000,
        'lossPercent': packets != null && lost != null && packets + lost > 0 ? lost * 100 / (packets + lost) : null,
        'concealedSamples': delta('concealedSamples'), 'concealmentEvents': delta('concealmentEvents'),
        'audioLevel': level == null || level > 1 ? null : level,
      };
    }).toList();
  }
}
