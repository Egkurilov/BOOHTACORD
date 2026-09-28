import 'dart:async';

typedef TrackEndedCallback = void Function();

/// Routes native track-ended events to their matching Dart media tracks.
class TrackEndedEventDispatcher {
  TrackEndedEventDispatcher(Stream<Map<String, dynamic>> events) {
    _subscription = events.listen(_handleEvent);
  }

  final Map<String, Set<TrackEndedCallback>> _callbacks = {};
  late final StreamSubscription<Map<String, dynamic>> _subscription;

  void register(String trackId, TrackEndedCallback callback) {
    _callbacks.putIfAbsent(trackId, () => <TrackEndedCallback>{}).add(callback);
  }

  void unregister(String trackId, TrackEndedCallback callback) {
    final callbacks = _callbacks[trackId];
    callbacks?.remove(callback);
    if (callbacks?.isEmpty ?? false) _callbacks.remove(trackId);
  }

  void _handleEvent(Map<String, dynamic> message) {
    final event = message['onTrackEnded'];
    if (event is! Map) return;
    final trackId = event['trackId'];
    if (trackId is! String) return;

    final callbacks = _callbacks.remove(trackId);
    if (callbacks == null) return;
    for (final callback in callbacks) {
      callback();
    }
  }

  Future<void> dispose() async {
    _callbacks.clear();
    await _subscription.cancel();
  }
}
