import 'dart:typed_data';

import 'package:image/image.dart' as image;

const screenThumbnailTopic = 'boohtacord.screen.thumbnail.v1';
const maxScreenThumbnailBytes = 14 * 1024;

enum ScreenThumbnailPublishResult {
  cancelled,
  captureFailed,
  encodingFailed,
  invalidThumbnail,
  publishFailed,
  published,
}

Future<ScreenThumbnailPublishResult> publishScreenThumbnailFrame({
  required Future<Uint8List> Function() capture,
  required Future<Uint8List?> Function(Uint8List frame) encode,
  required void Function(Uint8List thumbnail) storeLocally,
  required Future<void> Function(Uint8List thumbnail) publish,
  required bool Function() isActive,
}) async {
  late final Uint8List frame;
  try {
    frame = await capture();
  } catch (_) {
    return ScreenThumbnailPublishResult.captureFailed;
  }

  late final Uint8List? thumbnail;
  try {
    thumbnail = await encode(frame);
  } catch (_) {
    return ScreenThumbnailPublishResult.encodingFailed;
  }

  if (!isActive()) return ScreenThumbnailPublishResult.cancelled;
  if (thumbnail == null || !validScreenThumbnail(thumbnail)) {
    return ScreenThumbnailPublishResult.invalidThumbnail;
  }

  storeLocally(thumbnail);
  try {
    await publish(thumbnail);
  } catch (_) {
    return ScreenThumbnailPublishResult.publishFailed;
  }
  return ScreenThumbnailPublishResult.published;
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
