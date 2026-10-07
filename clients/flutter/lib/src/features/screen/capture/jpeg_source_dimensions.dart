import 'dart:typed_data';

import 'package:livekit_client/livekit_client.dart';

/// Reads native desktop-preview dimensions without decoding JPEG pixels.
VideoDimensions? sourceDimensionsFromJpeg(Uint8List? bytes) {
  if (bytes == null ||
      bytes.length < 4 ||
      bytes[0] != 0xff ||
      bytes[1] != 0xd8) {
    return null;
  }

  const frameMarkers = {
    0xc0,
    0xc1,
    0xc2,
    0xc3,
    0xc5,
    0xc6,
    0xc7,
    0xc9,
    0xca,
    0xcb,
    0xcd,
    0xce,
    0xcf,
  };
  var offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset] != 0xff) {
      offset++;
      continue;
    }
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) return null;
    final marker = bytes[offset++];
    if (marker == 0xd9 || marker == 0xda) return null;
    if (marker == 0xd8 ||
        marker == 0x01 ||
        (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (offset + 1 >= bytes.length) return null;
    final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) {
      return null;
    }
    if (frameMarkers.contains(marker)) {
      if (segmentLength < 7) return null;
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      if (width <= 0 || height <= 0) return null;
      return VideoDimensions(width, height);
    }
    offset += segmentLength;
  }
  return null;
}
