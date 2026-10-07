import 'counter_window.dart';
import 'models.dart';

export 'models.dart';

class _PreviousScreenSenderLayer {
  const _PreviousScreenSenderLayer(this.counters, this.receivedAtMs);
  final ScreenSenderLayerCounters counters;
  final double receivedAtMs;
}

class ScreenSenderLayerSampler {
  static const _maximumAgeMs = 10000.0;
  Map<String, _PreviousScreenSenderLayer> _previous = {};
  void clear() => _previous = {};

  ScreenSenderLayerSample sample(List<ScreenSenderLayerCounters> rows, double receivedAtMs) {
    final next = <String, _PreviousScreenSenderLayer>{};
    final layers = <ScreenSenderLayerMetrics>[];
    for (final row in rows.take(8)) {
      final id = row.id;
      final prior = _previous[id];
      final previous = prior?.counters;
      final elapsed = previous == null ? 0.0 : row.timestampMs - previous.timestampMs;
      final gap = prior == null ? 0.0 : receivedAtMs - prior.receivedAtMs;
      final stale = prior != null && (!gap.isFinite || gap > _maximumAgeMs || elapsed > _maximumAgeMs);
      final validWindow = prior != null && gap > 0 && gap <= _maximumAgeMs && elapsed > 0 && elapsed <= _maximumAgeMs;
      final reset = validWindow && screenCounterReset([
        (row.framesSent, previous?.framesSent), (row.bytesSent, previous?.bytesSent),
        (row.packetsSent, previous?.packetsSent), (row.packetsLost, previous?.packetsLost),
        (row.retransmittedPackets, previous?.retransmittedPackets), (row.nackCount, previous?.nackCount),
        (row.pliCount, previous?.pliCount), (row.firCount, previous?.firCount),
      ]);
      final interval = validWindow && !reset;
      double? delta(num? current, num? before) {
        if (!interval ||
            current == null ||
            before == null ||
            !screenCounterValid(current) ||
            !screenCounterValid(before) ||
            current < before) {
          return null;
        }
        return current.toDouble() - before.toDouble();
      }
      final frames = delta(row.framesSent, previous?.framesSent);
      final bytes = delta(row.bytesSent, previous?.bytesSent);
      final sent = delta(row.packetsSent, previous?.packetsSent);
      final lost = delta(row.packetsLost, previous?.packetsLost);
      final repeated = delta(row.retransmittedPackets, previous?.retransmittedPackets);
      final nacks = delta(row.nackCount, previous?.nackCount);
      final plis = delta(row.pliCount, previous?.pliCount);
      final firs = delta(row.firCount, previous?.firCount);
      final state = stale ? 'STALE' : reset ? 'UNKNOWN' : frames != null
          ? frames > 0 ? 'ACTIVE' : 'INACTIVE' : 'UNKNOWN';
      double? rate(double? value, double multiplier) => state == 'ACTIVE' && interval && value != null
          ? value * multiplier / elapsed : null;
      int? dimension(num? value) => screenCounterPixelDimension(value);
      layers.add(ScreenSenderLayerMetrics(id: id, rid: row.rid, codec: row.codec,
        state: state, width: dimension(row.width), height: dimension(row.height),
        framesPerSecond: rate(frames, 1000), bitrateBps: rate(bytes, 8000),
        retransmittedPacketsPerSecond: rate(repeated, 1000),
        packetLossPercent: state == 'ACTIVE' && sent != null && lost != null && sent + lost > 0
            ? lost * 100 / (sent + lost) : null,
        nackPerSecond: rate(nacks, 1000), pliPerSecond: rate(plis, 1000),
        firPerSecond: rate(firs, 1000), qualityLimitationReason: row.qualityLimitationReason));
      if (row.timestampMs.isFinite && receivedAtMs.isFinite) next[id] = _PreviousScreenSenderLayer(row, receivedAtMs);
    }
    _previous = next;
    final active = layers.where((layer) => layer.state == 'ACTIVE').toList()
      ..sort((a, b) => (b.width ?? 0) * (b.height ?? 0) - (a.width ?? 0) * (a.height ?? 0));
    return ScreenSenderLayerSample(List.unmodifiable(layers), active.isEmpty ? null : active.first);
  }

}
