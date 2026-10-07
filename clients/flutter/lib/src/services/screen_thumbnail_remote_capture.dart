import 'dart:typed_data';

import 'screen_thumbnail.dart';

/// Captures one thumbnail only after the receiver has decoded a real frame.
/// The bounded attempts ensure stale/unpublished tracks don't keep polling.
Future<Uint8List?> captureRemoteScreenThumbnail({
  required Future<bool> Function() hasDecodedFrames,
  required Future<Uint8List> Function() capture,
  required Future<Uint8List?> Function(Uint8List frame) encode,
  required bool Function() isActive,
  Future<void> Function(Duration duration)? wait,
  int maxAttempts = 12,
  Duration retryInterval = const Duration(milliseconds: 250),
}) async {
  final pause = wait ?? Future<void>.delayed;
  for (var attempt = 0; attempt < maxAttempts && isActive(); attempt++) {
    try {
      if (await hasDecodedFrames() && isActive()) {
        final bytes = await capture();
        if (!isActive()) return null;
        final thumbnail = await encode(bytes);
        if (isActive() &&
            thumbnail != null &&
            validScreenThumbnail(thumbnail)) {
          return thumbnail;
        }
      }
    } catch (_) {
      // A transient stats/capture error must not interrupt voice or video.
    }
    if (attempt + 1 < maxAttempts && isActive()) await pause(retryInterval);
  }
  return null;
}
