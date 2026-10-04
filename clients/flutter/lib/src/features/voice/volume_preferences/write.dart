part of 'state.dart';
extension _VolumeWrites on VoiceVolumePreferences {
  Future<void> _schedule() {
    _payload = jsonEncode({'version': 2, 'volumes': _values.map((id, level) => MapEntry(id, level.toJson()))});
    if (_batch == null) {
      _batch = Completer<void>();
      unawaited(_batch!.future.catchError((Object _) {}));
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 250), () => unawaited(_flush().catchError((Object _) {})));
    return _batch!.future;
  }
  Future<void> _flush() {
    _timer?.cancel(); _timer = null;
    final payload = _payload, batch = _batch;
    _payload = null; _batch = null;
    if (payload == null || batch == null) return _tail;
    Future<void> write() async {
      try {
        final saved = _origin.isEmpty || _storage == null ? false : await _storage.setString(key, payload);
        if (saved != true) throw StateError('Volume preferences unavailable');
        status = 'success'; batch.complete();
      } catch (_) {
        status = 'fallback';
        final error = StateError('Volume preferences unavailable');
        batch.completeError(error);
        throw error;
      }
    }
    final next = _tail.then((_) => write());
    _tail = next.catchError((Object _) {});
    return next;
  }
}
