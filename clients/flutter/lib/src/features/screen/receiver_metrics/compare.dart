import 'models.dart';

ScreenReceiverMetrics compareScreenReceiverStats(
  ScreenReceiverSnapshot? previous,
  ScreenReceiverSnapshot current,
) {
  final same = previous?.streamId == current.streamId && previous?.ssrc == current.ssrc;
  final elapsed = previous == null || !same ? null : current.timestampMs - previous.timestampMs;
  final reset = [(current.framesDecoded, previous?.framesDecoded), (current.bytesReceived, previous?.bytesReceived), (current.packetsReceived, previous?.packetsReceived)].any((pair) => pair.$1 != null && pair.$2 != null && pair.$1! < pair.$2!);
  final elapsedMs = elapsed != null && elapsed > 0 && elapsed <= 10000 && !reset ? elapsed : null;
  final frames = _delta(previous?.framesDecoded, current.framesDecoded, elapsedMs);
  final decode = _delta(previous?.totalDecodeTime, current.totalDecodeTime, elapsedMs);
  final emitted = _delta(previous?.jitterBufferEmittedCount, current.jitterBufferEmittedCount, elapsedMs);
  final delay = _delta(previous?.jitterBufferDelay, current.jitterBufferDelay, elapsedMs);
  return ScreenReceiverMetrics(
    statsWindowMs: elapsedMs, collectionState: elapsed != null && elapsed > 10000 ? 'stale' : elapsedMs == null || frames == null ? 'unknown' : frames == 0 ? 'inactive' : 'active',
    decodeMsPerFrame: frames != null && frames > 0 && decode != null ? decode * 1000 / frames : null,
    jitterBufferMsPerFrame: emitted != null && emitted > 0 && delay != null ? delay * 1000 / emitted : null,
    nackPerSecond: _rate(previous?.nackCount, current.nackCount, elapsedMs, 1000),
    pliPerSecond: _rate(previous?.pliCount, current.pliCount, elapsedMs, 1000),
    firPerSecond: _rate(previous?.firCount, current.firCount, elapsedMs, 1000),
    freezeCount: _finiteNonNegative(current.freezeCount) ? current.freezeCount : null,
    freezeDurationMs: _finiteNonNegative(current.totalFreezesDuration) ? current.totalFreezesDuration! * 1000 : null,
    receivedFps: _rate(
      previous?.framesReceived,
      current.framesReceived,
      elapsedMs,
      1000,
    ),
    bitrateKbps: _rate(
      previous?.bytesReceived,
      current.bytesReceived,
      elapsedMs,
      8,
    ),
    decodedFps: _rate(
      previous?.framesDecoded,
      current.framesDecoded,
      elapsedMs,
      1000,
    ),
    // WebRTC framesRendered / texture upload does not prove native presentation.
    presentedFps: null,
    droppedFrames: _delta(
      previous?.framesDropped,
      current.framesDropped,
      elapsedMs,
    ),
    jitterMs: _finiteNonNegative(current.jitterSeconds)
        ? current.jitterSeconds! * 1000
        : null,
    packetsLost: _finiteNonNegative(current.packetsLost)
        ? current.packetsLost
        : null,
  );
}

double? _rate(
  double? previous,
  double? current,
  double? elapsedMs,
  double multiplier,
) {
  if (!_finiteNonNegative(previous) ||
      !_finiteNonNegative(current) ||
      !_finiteNonNegative(elapsedMs) ||
      elapsedMs == 0 ||
      current! < previous!) {
    return null;
  }
  return _round((current - previous) * multiplier / elapsedMs!, 1);
}

double? _delta(double? previous, double? current, double? elapsedMs) {
  if (!_finiteNonNegative(previous) ||
      !_finiteNonNegative(current) ||
      !_finiteNonNegative(elapsedMs) ||
      elapsedMs == 0 ||
      current! < previous!) {
    return null;
  }
  return current - previous;
}

bool _finiteNonNegative(double? value) =>
    value != null && value.isFinite && value >= 0;

double _round(double value, int places) {
  final multiplier = switch (places) {
    0 => 1.0,
    1 => 10.0,
    _ => 100.0,
  };
  return (value * multiplier).round() / multiplier;
}
