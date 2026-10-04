import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _avatarDimension = 128;
const _maxAvatarBytes = 2 * 1024 * 1024;
const _maxAvatarSourceDimension = 4096;

Uint8List? normalizeAvatarImage(Uint8List bytes, String contentType) {
  if (bytes.isEmpty || bytes.length > _maxAvatarBytes) return null;
  final isPng = contentType == 'image/png' && _hasPngSignature(bytes);
  final isJpeg = contentType == 'image/jpeg' && _hasJpegSignature(bytes);
  if (!isPng && !isJpeg) return null;

  final decoder = isPng ? image.PngDecoder() : image.JpegDecoder();
  final dimensions = decoder.startDecode(bytes);
  if (dimensions == null ||
      dimensions.width < 1 ||
      dimensions.height < 1 ||
      dimensions.width > _maxAvatarSourceDimension ||
      dimensions.height > _maxAvatarSourceDimension) {
    return null;
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) return null;
  final source = image.bakeOrientation(decoded);

  final side = source.width < source.height ? source.width : source.height;
  final cropped = image.copyCrop(
    source,
    x: (source.width - side) ~/ 2,
    y: (source.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = image.copyResize(
    cropped,
    width: _avatarDimension,
    height: _avatarDimension,
    interpolation: image.Interpolation.linear,
  );
  final normalized = Uint8List.fromList(image.encodePng(resized));
  return normalized.isNotEmpty && normalized.length <= _maxAvatarBytes
      ? normalized
      : null;
}

bool _hasPngSignature(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4e &&
    bytes[3] == 0x47 &&
    bytes[4] == 0x0d &&
    bytes[5] == 0x0a &&
    bytes[6] == 0x1a &&
    bytes[7] == 0x0a;

bool _hasJpegSignature(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;
