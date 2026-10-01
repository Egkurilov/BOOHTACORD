import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/system_clipboard_paste.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves clipboard text and reads an accompanying PNG', () async {
    final image = Uint8List.fromList([1, 2, 3]);
    final content = await readSystemClipboardPaste(
      readClipboard: () async =>
          EnhancedClipboardData(text: 'caption', imageBytes: image),
    );

    expect(content?.text, 'caption');
    expect(content?.image?.bytes, image);
    expect(content?.image?.fileName, 'clipboard-image.png');
    expect(content?.imageError, isNull);
  });

  test('keeps plain text and rejects PNGs above the upload cap', () async {
    final content = await readSystemClipboardPaste(
      readClipboard: () async =>
          EnhancedClipboardData(text: 'caption', imageBytes: Uint8List(5)),
      maxImageBytes: 4,
    );

    expect(content?.text, 'caption');
    expect(content?.image, isNull);
    expect(content?.imageError, contains('25 МБ'));
  });

  test('returns null for an empty clipboard', () async {
    final content = await readSystemClipboardPaste(
      readClipboard: () async => EnhancedClipboardData(),
    );

    expect(content, isNull);
  });
}
