import 'dart:async';

import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes captures that share the native temporary-frame file', () async {
    final queue = ScreenThumbnailCaptureQueue();
    final firstStarted = Completer<void>();
    final finishFirst = Completer<void>();
    var secondStarted = false;
    final first = queue.run(() async {
      firstStarted.complete();
      await finishFirst.future;
      return 'first';
    });
    await firstStarted.future;
    final second = queue.run(() async {
      secondStarted = true;
      return 'second';
    });

    await Future<void>.delayed(Duration.zero);
    expect(secondStarted, isFalse);
    finishFirst.complete();
    expect(await first, 'first');
    expect(await second, 'second');
    expect(secondStarted, isTrue);
  });
}
