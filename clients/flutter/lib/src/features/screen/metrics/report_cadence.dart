class ScreenShareReportCadence {
  static const intervalMs = 5000.0;
  double? _lastReportAtMs;

  bool isDue(double nowMs) {
    if (!nowMs.isFinite) return false;
    final last = _lastReportAtMs;
    if (last == null || nowMs < last || nowMs - last >= intervalMs) {
      _lastReportAtMs = nowMs;
      return true;
    }
    return false;
  }

  void clear() => _lastReportAtMs = null;
}
