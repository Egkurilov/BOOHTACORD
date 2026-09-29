import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('compresses a captured frame to a bounded JPEG preview', () {
    final source = image.Image(width: 640, height: 360);
    final png = Uint8List.fromList(image.encodePng(source));
    final thumbnail = encodeScreenThumbnail(png);
    expect(thumbnail, isNotNull);
    expect(thumbnail!.length, lessThanOrEqualTo(14 * 1024));
    expect(image.decodeJpg(thumbnail)?.width, 160);
  });

  test('ignores malformed thumbnail packets', () {
    expect(validScreenThumbnail(Uint8List.fromList([1, 2, 3])), isFalse);
    expect(validScreenThumbnail(Uint8List(15 * 1024)), isFalse);
  });
}
