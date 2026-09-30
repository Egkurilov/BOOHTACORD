class ScreenPacketLossWindow {
  final List<_Sample> _samples = [];
  double? durationMs;
  bool? _sender;

  void clear() {
    _samples.clear();
    durationMs = null;
    _sender = null;
  }

  double? add({
    required double timestampMs,
    double? packetsReceived,
    double? packetsSent,
    required double? packetsLost,
  }) {
    durationMs = null;
    final sender = packetsSent != null;
    if (_sender != null && _sender != sender) clear();
    final count = packetsSent ?? packetsReceived;
    if (!_valid(timestampMs) || !_valid(count) || !_valid(packetsLost)) {
      clear();
      return null;
    }
    final received = count!;
    final lost = packetsLost!;
    final last = _samples.isEmpty ? null : _samples.last;
    if (last != null &&
        (timestampMs <= last.timestampMs ||
            received < last.received ||
            lost < last.lost)) {
      clear();
    }
    _sender = sender;
    _samples.add(_Sample(timestampMs, received, lost));
    final cutoff = timestampMs - 10000;
    while (_samples.length > 1 && _samples[1].timestampMs <= cutoff) {
      _samples.removeAt(0);
    }
    while (_samples.length > 1 &&
        timestampMs - _samples.first.timestampMs > 12000) {
      _samples.removeAt(0);
    }
    final baseline = _samples.first;
    final elapsedMs = timestampMs - baseline.timestampMs;
    if (elapsedMs > 12000) {
      _samples
        ..clear()
        ..add(_Sample(timestampMs, received, lost));
      return null;
    }
    if (elapsedMs < 9000) return null;
    final receivedDelta = received - baseline.received;
    final lostDelta = lost - baseline.lost;
    final total = sender ? receivedDelta : receivedDelta + lostDelta;
    if (total <= 0 || lostDelta > total) return null;
    durationMs = elapsedMs;
    return ((lostDelta / total) * 10000).round() / 100;
  }
}

String formatScreenPacketLossPercent(double? value) {
  if (!_valid(value)) return 'Нет данных';
  final rendered = value!
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .replaceAll('.', ',');
  return '$rendered %';
}

bool _valid(double? value) => value != null && value.isFinite && value >= 0;

class _Sample {
  const _Sample(this.timestampMs, this.received, this.lost);

  final double timestampMs;
  final double received;
  final double lost;
}
