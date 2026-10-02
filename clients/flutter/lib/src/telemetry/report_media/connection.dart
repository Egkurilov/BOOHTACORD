import 'package:livekit_client/livekit_client.dart';

class ConnectionMediaReporter {
  ConnectionMediaReporter(this._send, this.platform, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final Future<void> Function(Map<String, Object>) _send;
  final String platform;
  final DateTime Function() _now;
  DateTime? _last;
  bool _busy = false;

  Future<void> submit(int? measuredPing, ConnectionQuality quality) async {
    final now = _now();
    if (_busy ||
        (_last != null &&
            now.difference(_last!) < const Duration(seconds: 5))) {
      return;
    }
    _last = now;
    _busy = true;
    try {
      await _send({
        'platform': platform,
        'direction': 'connection',
        'state': 'playing',
        'connection_quality': quality.name.toUpperCase(),
        'sample_age_ms': 0,
        if (measuredPing != null && measuredPing >= 0 && measuredPing <= 60000)
          'rtt_ms': measuredPing,
      });
    } catch (_) {
      // Media and voice controls must remain independent of telemetry delivery.
    } finally {
      _busy = false;
    }
  }
}
