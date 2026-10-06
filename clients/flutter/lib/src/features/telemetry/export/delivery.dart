part of 'session_processor.dart';

extension _Delivery on SessionSpanProcessor {
  void dropStale() {
    _queue.removeWhere((span) {
      final stale = !(_owners[span]?.current ?? false);
      if (stale) telemetryExportStatus.dropped++;
      return stale;
    });
    telemetryExportStatus.queued = _queue.length;
  }

  Future<void> _flush() async {
    dropStale();
    final batch = _queue.take(16).toList();
    _queue.removeRange(0, batch.length);
    telemetryExportStatus.queued = _queue.length;
    if (batch.isEmpty || _stopped) return;
    final body = OtlpSpanTransformer.transformSpans(batch).writeToBuffer();
    if (body.length > 262144) {
      telemetryExportStatus.dropped += batch.length;
      return;
    }
    for (var attempt = 0; attempt <= 2; attempt++) {
      if (_stopped || batch.any((span) => !(_owners[span]?.current ?? false))) {
        telemetryExportStatus.dropped += batch.length;
        return;
      }
      try {
        await send(body).timeout(const Duration(seconds: 3));
        return;
      } catch (error) {
        final retry =
            error is! RelayFailure ||
            error.status == 429 ||
            error.status >= 500;
        if (!retry || attempt == 2) {
          telemetryExportStatus.dropped += batch.length;
          return;
        }
        telemetryExportStatus.retried++;
        final wait = error is RelayFailure
            ? error.retryAfter
            : Duration(milliseconds: 250 * (attempt + 1));
        await Future<void>.delayed(
          Duration(milliseconds: wait.inMilliseconds.clamp(100, 2000)),
        );
      }
    }
  }
}
