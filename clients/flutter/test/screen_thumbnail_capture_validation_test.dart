import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validJpeg = [0xff, 0xd8, 0xff, 0xd9];

  test('rejects invalid JPEG before local storage', () async {
    var stored = false;
    final result = await captureScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => Uint8List.fromList([1, 2, 3]),
      storeLocally: (_) => stored = true,
      isActive: () => true,
    );

    expect(result, ScreenThumbnailCaptureResult.invalidThumbnail);
    expect(stored, isFalse);
  });

  test('stores a valid bounded thumbnail locally', () async {
    final thumbnail = Uint8List.fromList(validJpeg);
    Uint8List? stored;
    final result = await captureScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => thumbnail,
      storeLocally: (bytes) => stored = bytes,
      isActive: () => true,
    );

    expect(result, ScreenThumbnailCaptureResult.captured);
    expect(stored, same(thumbnail));
  });
}
