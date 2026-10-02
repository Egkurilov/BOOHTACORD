/// Prevents a pending stats request for an old screen-share track from
/// blocking sampling after the track is stopped or replaced.
class ScreenShareMetricsGenerationGate {
  int _generation = 0;
  int? _busyGeneration;

  int get generation => _generation;

  int nextGeneration() {
    _generation++;
    _busyGeneration = null;
    return _generation;
  }

  bool tryEnter(int generation) {
    if (generation != _generation || _busyGeneration == generation) {
      return false;
    }
    _busyGeneration = generation;
    return true;
  }

  void leave(int generation) {
    if (_busyGeneration == generation) _busyGeneration = null;
  }
}
