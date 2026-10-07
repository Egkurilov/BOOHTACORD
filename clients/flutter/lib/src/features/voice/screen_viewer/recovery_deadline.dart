class ScreenViewerRecoveryDeadline {
  ScreenViewerRecoveryDeadline({
    Duration timeout = const Duration(seconds: 5),
    Duration Function()? monotonicNow,
  }) : _timeout = timeout,
       _monotonicNow = monotonicNow ?? _createMonotonicClock(),
       _remaining = timeout;

  final Duration _timeout;
  final Duration Function() _monotonicNow;
  Duration _remaining;
  Duration _startedAt = Duration.zero;
  bool _running = false;

  Duration get remaining {
    if (!_running) return _remaining;
    final value = _remaining - (_monotonicNow() - _startedAt);
    return value.isNegative ? Duration.zero : value;
  }

  void start() {
    if (_running || remaining == Duration.zero) return;
    _startedAt = _monotonicNow();
    _running = true;
  }

  void pause() {
    if (!_running) return;
    _remaining = remaining;
    _running = false;
  }

  void reset() {
    _remaining = _timeout;
    _running = false;
  }

  void expire() {
    _remaining = Duration.zero;
    _running = false;
  }
}

Duration Function() _createMonotonicClock() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}
