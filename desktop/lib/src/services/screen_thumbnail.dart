import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const maxScreenThumbnailBytes = 14 * 1024;

enum ScreenThumbnailCaptureResult {
  cancelled,
  captureFailed,
  encodingFailed,
  invalidThumbnail,
  captured,
}

Future<ScreenThumbnailCaptureResult> captureScreenThumbnailFrame({
  required Future<Uint8List> Function() capture,
  required Future<Uint8List?> Function(Uint8List frame) encode,
  required void Function(Uint8List thumbnail) storeLocally,
  required bool Function() isActive,
}) async {
  late final Uint8List frame;
  try {
    frame = await capture();
  } catch (_) {
    return ScreenThumbnailCaptureResult.captureFailed;
  }

  late final Uint8List? thumbnail;
  try {
    thumbnail = await encode(frame);
  } catch (_) {
    return ScreenThumbnailCaptureResult.encodingFailed;
  }

  if (!isActive()) return ScreenThumbnailCaptureResult.cancelled;
  if (thumbnail == null || !validScreenThumbnail(thumbnail)) {
    return ScreenThumbnailCaptureResult.invalidThumbnail;
  }

  storeLocally(thumbnail);
  return ScreenThumbnailCaptureResult.captured;
}

Uint8List? screenThumbnailForIdentity(
  Map<String, Uint8List> thumbnails,
  String? identity,
) => identity == null ? null : thumbnails[identity];

Uint8List? encodeScreenThumbnail(Uint8List frame) {
  final decoded = image.decodeImage(frame);
  if (decoded == null) return null;
  for (final (width, quality) in [(160, 45), (128, 35), (96, 25)]) {
    final resized = image.copyResize(decoded, width: width);
    final encoded = Uint8List.fromList(
      image.encodeJpg(resized, quality: quality),
    );
    if (validScreenThumbnail(encoded)) return encoded;
  }
  return null;
}

bool validScreenThumbnail(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes.length <= maxScreenThumbnailBytes &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[bytes.length - 2] == 0xff &&
    bytes.last == 0xd9;

/// Serializes native `captureFrame()` calls, which currently share a temporary
/// PNG path inside flutter_webrtc.
class ScreenThumbnailCaptureQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

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
