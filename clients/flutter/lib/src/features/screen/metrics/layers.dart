class ScreenSenderLayerCounters {
  const ScreenSenderLayerCounters({required this.streamId, required this.rid,
    required this.codec, required this.timestampMs, required this.width,
    required this.height, required this.framesSent, required this.bytesSent,
    required this.packetsSent, required this.packetsLost,
    required this.retransmittedPackets, this.nackCount, this.pliCount,
    this.firCount, this.qualityLimitationReason});
  final String streamId;
  final String? rid;
  final String? codec;
  final double timestampMs;
  final num? width, height, framesSent, bytesSent, packetsSent, packetsLost;
  final num? retransmittedPackets;
  final num? nackCount, pliCount, firCount;
  final String? qualityLimitationReason;
}

class ScreenSenderLayerMetrics {
  const ScreenSenderLayerMetrics({required this.id, required this.rid,
    required this.codec, required this.state, required this.width,
    required this.height, required this.framesPerSecond, required this.bitrateBps,
    required this.retransmittedPacketsPerSecond, required this.packetLossPercent,
    required this.nackPerSecond, required this.pliPerSecond, required this.firPerSecond,
    required this.qualityLimitationReason});
  final String id;
  final String? rid, codec;
  final String state;
  final int? width, height;
  final double? framesPerSecond, bitrateBps, retransmittedPacketsPerSecond;
  final double? packetLossPercent;
  final double? nackPerSecond, pliPerSecond, firPerSecond;
  final String? qualityLimitationReason;
}

class ScreenSenderLayerSample {
  const ScreenSenderLayerSample(this.layers, this.selected);
  final List<ScreenSenderLayerMetrics> layers;
  final ScreenSenderLayerMetrics? selected;
}

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
      final id = '${row.streamId}:${row.rid ?? ''}';
      final prior = _previous[id];
      final previous = prior?.counters;
      final elapsed = previous == null ? 0.0 : row.timestampMs - previous.timestampMs;
      final gap = prior == null ? 0.0 : receivedAtMs - prior.receivedAtMs;
      final stale = prior != null && (!gap.isFinite || gap > _maximumAgeMs || elapsed > _maximumAgeMs);
      final interval = prior != null && gap > 0 && gap <= _maximumAgeMs && elapsed > 0 && elapsed <= _maximumAgeMs;
      double? delta(num? current, num? before) => interval && _counter(current) &&
          _counter(before) && current! >= before! ? current!.toDouble() - before!.toDouble() : null;
      final frames = delta(row.framesSent, previous?.framesSent);
      final bytes = delta(row.bytesSent, previous?.bytesSent);
      final sent = delta(row.packetsSent, previous?.packetsSent);
      final lost = delta(row.packetsLost, previous?.packetsLost);
      final repeated = delta(row.retransmittedPackets, previous?.retransmittedPackets);
      final nacks = delta(row.nackCount, previous?.nackCount);
      final plis = delta(row.pliCount, previous?.pliCount);
      final firs = delta(row.firCount, previous?.firCount);
      final reset = interval && [
        [row.framesSent, previous?.framesSent], [row.bytesSent, previous?.bytesSent],
        [row.packetsSent, previous?.packetsSent], [row.packetsLost, previous?.packetsLost],
      ].any((pair) => _counter(pair[0]) && _counter(pair[1]) && pair[0]! < pair[1]!);
      final progressed = [frames, bytes, sent].any((value) => value != null && value > 0);
      final state = stale ? 'STALE' : reset ? 'UNKNOWN' : progressed ? 'ACTIVE' : interval ? 'INACTIVE' : 'UNKNOWN';
      double? rate(double? value, double multiplier) => state == 'ACTIVE' && interval && value != null
          ? value * multiplier / elapsed : null;
      int? dimension(num? value) => _counter(value) && value! > 0 ? value.round() : null;
      layers.add(ScreenSenderLayerMetrics(id: id, rid: row.rid, codec: row.codec,
        state: state, width: dimension(row.width), height: dimension(row.height),
        framesPerSecond: rate(frames, 1000), bitrateBps: rate(bytes, 8000),
        retransmittedPacketsPerSecond: rate(repeated, 1000),
        packetLossPercent: sent != null && lost != null && sent + lost > 0 ? lost * 100 / (sent + lost) : null,
        nackPerSecond: rate(nacks, 1000), pliPerSecond: rate(plis, 1000),
        firPerSecond: rate(firs, 1000), qualityLimitationReason: row.qualityLimitationReason));
      if (row.timestampMs.isFinite && receivedAtMs.isFinite) next[id] = _PreviousScreenSenderLayer(row, receivedAtMs);
    }
    _previous = next;
    final active = layers.where((layer) => layer.state == 'ACTIVE').toList()
      ..sort((a, b) => (b.width ?? 0) * (b.height ?? 0) - (a.width ?? 0) * (a.height ?? 0));
    return ScreenSenderLayerSample(List.unmodifiable(layers), active.isEmpty ? null : active.first);
  }

  bool _counter(num? value) => value != null && value.isFinite && value >= 0;
}
