import 'package:livekit_client/livekit_client.dart';

VideoDimensions? screenShareCaptureDimensions(LocalVideoTrack track) {
  try {
    final settings = track.mediaStreamTrack.getSettings();
    final width = settings['width'];
    final height = settings['height'];
    if (width is num && height is num && width > 0 && height > 0) {
      return VideoDimensions(width.round(), height.round());
    }
  } catch (_) {
    // Some platform implementations don't expose capture settings.
  }
  return null;
}
