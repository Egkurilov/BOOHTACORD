import 'dart:async';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validJpeg = [0xff, 0xd8, 0xff, 0xd9];

  test('captures only after the remote receiver decoded a frame', () async {
    var statsReads = 0;
    var captures = 0;
    var waits = 0;

    final result = await captureRemoteScreenThumbnail(
      hasDecodedFrames: () async => ++statsReads >= 3,
      capture: () async {
        captures++;
        return Uint8List.fromList([1]);
      },
      encode: (_) async => Uint8List.fromList(validJpeg),
      isActive: () => true,
      wait: (_) async => waits++,
    );

    expect(result, Uint8List.fromList(validJpeg));
    expect(statsReads, 3);
    expect(captures, 1);
    expect(waits, 2);
  });

  test('stops the bounded receiver capture when the stream becomes inactive', () async {
    var active = true;
    var statsReads = 0;
    var captures = 0;

    final result = await captureRemoteScreenThumbnail(
      hasDecodedFrames: () async {
        statsReads++;
        active = false;
        return false;
      },
      capture: () async {
        captures++;
        return Uint8List.fromList([1]);
      },
      encode: (_) async => Uint8List.fromList(validJpeg),
      isActive: () => active,
      wait: (_) async {},
    );

    expect(result, isNull);
    expect(statsReads, 1);
    expect(captures, 0);
  });

  test('gives up after the preview deadline when no video frame is decoded', () async {
    var statsReads = 0;
    var captures = 0;
    var waits = 0;

    final result = await captureRemoteScreenThumbnail(
      hasDecodedFrames: () async {
        statsReads++;
        return false;
      },
      capture: () async {
        captures++;
        return Uint8List.fromList([1]);
      },
      encode: (_) async => Uint8List.fromList(validJpeg),
      isActive: () => true,
      wait: (_) async => waits++,
      maxAttempts: 4,
    );

    expect(result, isNull);
    expect(statsReads, 4);
    expect(captures, 0);
    expect(waits, 3);
  });

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

  test(
    'reports capture failure without attempting encode or storing',
    () async {
      var encoded = false;

      final result = await captureScreenThumbnailFrame(
        capture: () async => throw StateError('capture failed'),
        encode: (_) async {
          encoded = true;
          return Uint8List.fromList(validJpeg);
        },
        storeLocally: (_) {},
        isActive: () => true,
      );

      expect(result, ScreenThumbnailCaptureResult.captureFailed);
      expect(encoded, isFalse);
    },
  );

  test('reports encoding failure without storing', () async {
    final result = await captureScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => throw StateError('encode failed'),
      storeLocally: (_) {},
      isActive: () => true,
    );

    expect(result, ScreenThumbnailCaptureResult.encodingFailed);
  });

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

  test('does not store a frame after sharing stops', () async {
    var active = true;
    var stored = false;

    final result = await captureScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async {
        active = false;
        return Uint8List.fromList(validJpeg);
      },
      storeLocally: (_) => stored = true,
      isActive: () => active,
    );

    expect(result, ScreenThumbnailCaptureResult.cancelled);
    expect(stored, isFalse);
  });

}
