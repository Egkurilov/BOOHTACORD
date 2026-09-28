import 'dart:async';

typedef TrackEndedCallback = void Function();

/// Routes native track-ended events to their matching Dart media tracks.
class TrackEndedEventDispatcher {
  TrackEndedEventDispatcher(Stream<Map<String, dynamic>> events) {
    _subscription = events.listen(_handleEvent);
  }

  final Map<String, Set<TrackEndedCallback>> _callbacks = {};
  final Map<String, DateTime> _pendingEnded = {};
  final Map<String, DateTime> _recentlyEnded = {};
  late final StreamSubscription<Map<String, dynamic>> _subscription;

  static const _eventRetention = Duration(seconds: 30);
  static const _maxRememberedTrackIds = 32;

  void register(String trackId, TrackEndedCallback callback) {
    _pruneEndedEvents(DateTime.now());
    if (_pendingEnded.remove(trackId) != null) {
      _rememberRecentlyEnded(trackId, DateTime.now());
      callback();
      return;
    }
    if (_recentlyEnded.containsKey(trackId)) return;
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

    final now = DateTime.now();
    _pruneEndedEvents(now);
    if (_pendingEnded.containsKey(trackId) ||
        _recentlyEnded.containsKey(trackId)) {
      return;
    }

    final callbacks = _callbacks.remove(trackId);
    if (callbacks == null || callbacks.isEmpty) {
      _remember(_pendingEnded, trackId, now);
      return;
    }
    _rememberRecentlyEnded(trackId, now);
    for (final callback in callbacks) {
      callback();
    }
  }

  void _rememberRecentlyEnded(String trackId, DateTime now) {
    _remember(_recentlyEnded, trackId, now);
  }

  void _remember(Map<String, DateTime> events, String trackId, DateTime now) {
    events.remove(trackId);
    events[trackId] = now;
    while (events.length > _maxRememberedTrackIds) {
      events.remove(events.keys.first);
    }
  }

  void _pruneEndedEvents(DateTime now) {
    bool hasExpired(DateTime timestamp) =>
        now.difference(timestamp) > _eventRetention;
    _pendingEnded.removeWhere((_, timestamp) => hasExpired(timestamp));
    _recentlyEnded.removeWhere((_, timestamp) => hasExpired(timestamp));
  }

  Future<void> dispose() async {
    _callbacks.clear();
    _pendingEnded.clear();
    _recentlyEnded.clear();
    await _subscription.cancel();
  }
}
