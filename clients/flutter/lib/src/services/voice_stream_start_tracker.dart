/// Detects newly started remote screen shares without alerting on room entry
/// or on tracks that are restored after a reconnect.
class VoiceStreamStartTracker {
  Set<String> _known = {};
  Set<String> _recoveryKnown = {};
  bool _initialized = false;
  bool _recovering = false;

  String? observe(
    Iterable<String> remoteStreamIds, {
    required bool connected,
    required bool reconnecting,
  }) {
    if (reconnecting) {
      if (!_recovering) _recoveryKnown = Set<String>.of(_known);
      _recovering = true;
      return null;
    }
    if (!connected) {
      reset();
      return null;
    }

    final current = remoteStreamIds.toSet();
    if (!_initialized) {
      _known = current;
      _initialized = true;
      return null;
    }

    String? firstNew;
    for (final streamId in current) {
      if (!_known.contains(streamId)) {
        firstNew = streamId;
        break;
      }
    }
    if (_recovering && !_recoveryKnown.every(current.contains)) {
      _known.addAll(current);
      return firstNew;
    }

    _known = current;
    _recoveryKnown.clear();
    _recovering = false;
    return firstNew;
  }

  void reset() {
    _known.clear();
    _recoveryKnown.clear();
    _initialized = false;
    _recovering = false;
  }
}
