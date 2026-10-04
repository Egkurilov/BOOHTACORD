import 'dart:typed_data';

import 'package:boohtacord_desktop/src/features/profile/avatar/normalize_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('normalizes PNG and JPEG avatars to centered 128x128 PNGs', () {
    final source = image.Image(width: 320, height: 160);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, x < 160 ? 255 : 0, x < 160 ? 0 : 255, 0, 255);
      }
    }
    final png = Uint8List.fromList(image.encodePng(source));
    final jpeg = Uint8List.fromList(image.encodeJpg(source, quality: 95));

    for (final (bytes, contentType) in [
      (png, 'image/png'),
      (jpeg, 'image/jpeg'),
    ]) {
      final normalized = normalizeAvatarImage(bytes, contentType);
      expect(normalized, isNotNull);
      final decoded = image.decodeImage(normalized!)!;
      expect((decoded.width, decoded.height), (128, 128));
      expect(decoded.getPixel(31, 64).r, greaterThan(240));
      expect(decoded.getPixel(96, 64).g, greaterThan(240));
    }
  });

  test('rejects invalid data and unsupported content types', () {
    expect(
      normalizeAvatarImage(Uint8List.fromList([1, 2, 3]), 'image/png'),
      isNull,
    );
    expect(
      normalizeAvatarImage(Uint8List.fromList([1, 2, 3]), 'image/gif'),
      isNull,
    );
  });
}
