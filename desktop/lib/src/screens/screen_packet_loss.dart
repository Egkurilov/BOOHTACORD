class ScreenPacketLossWindow {
  final List<_Sample> _samples = [];

  void clear() => _samples.clear();

  double? add({
    required double timestampMs,
    required double? packetsReceived,
    required double? packetsLost,
  }) {
    if (!_valid(timestampMs) ||
        !_valid(packetsReceived) ||
        !_valid(packetsLost)) {
      clear();
      return null;
    }
    final received = packetsReceived!;
    final lost = packetsLost!;
    final last = _samples.isEmpty ? null : _samples.last;
    if (last != null &&
        (timestampMs <= last.timestampMs ||
            received < last.received ||
            lost < last.lost)) {
      clear();
    }
    _samples.add(_Sample(timestampMs, received, lost));
    final cutoff = timestampMs - 10000;
    while (_samples.length > 1 && _samples[1].timestampMs <= cutoff) {
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
    final total = receivedDelta + lostDelta;
    if (total <= 0) return null;
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
