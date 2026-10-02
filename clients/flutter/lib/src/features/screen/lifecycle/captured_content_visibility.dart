import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Tracks Android's captured-app visibility for exactly one local screen track.
class CapturedContentVisibilityState {
  String? _trackId;
  bool? isVisible;

  void track(String? trackId) {
    if (_trackId == trackId) return;
    _trackId = trackId;
    isVisible = null;
  }

  bool handle(CapturedContentVisibilityEvent event) {
    if (event.trackId != _trackId || isVisible == event.isVisible) return false;
    isVisible = event.isVisible;
    return true;
  }
}
