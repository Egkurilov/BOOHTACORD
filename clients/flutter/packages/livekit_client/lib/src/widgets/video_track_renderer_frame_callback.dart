import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// Connects a VideoTrackRenderer observer to the native renderer's first-frame
/// callback. On Android this callback is emitted after WebRTC swaps the first
/// rendered frame into the EGL surface.
void setVideoTrackRendererFirstFrameCallback(
  rtc.VideoRenderer renderer,
  VoidCallback? callback,
) {
  renderer.onFirstFrameRendered = callback;
}
