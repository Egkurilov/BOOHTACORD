import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// Connects a VideoTrackRenderer observer to the native renderer's first-frame
/// callback. Native backends signal when a frame reaches their renderer sink;
/// this does not by itself prove that the Flutter texture presented pixels.
void setVideoTrackRendererFirstFrameCallback(
  rtc.VideoRenderer renderer,
  VoidCallback? callback,
) {
  renderer.onFirstFrameRendered = callback;
}
