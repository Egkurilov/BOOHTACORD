import 'dart:typed_data';

import 'package:image/image.dart' as image;

const screenThumbnailTopic = 'boohtacord.screen.thumbnail.v1';
const maxScreenThumbnailBytes = 14 * 1024;

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
