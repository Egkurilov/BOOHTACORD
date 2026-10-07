import 'dart:async';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validJpeg = [0xff, 0xd8, 0xff, 0xd9];

  test('retries a local preview after native capture times out', () async {
    final queue = ScreenThumbnailCaptureQueue();
    var captureAttempts = 0;
    Uint8List? stored;

    Future<Uint8List> capture() async {
      captureAttempts++;
      if (captureAttempts == 1) {
        throw TimeoutException('No frame arrived before capture timeout.');
      }
      return Uint8List.fromList([1]);
    }

    final first = await captureScreenThumbnailFrame(
      capture: () => queue.run(capture),
      encode: (_) async => Uint8List.fromList(validJpeg),
      storeLocally: (_) {},
      isActive: () => true,
    );
    final retry = await captureScreenThumbnailFrame(
      capture: () => queue.run(capture),
      encode: (_) async => Uint8List.fromList(validJpeg),
      storeLocally: (thumbnail) => stored = thumbnail,
      isActive: () => true,
    );

    expect(first, ScreenThumbnailCaptureResult.captureFailed);
    expect(retry, ScreenThumbnailCaptureResult.captured);
    expect(captureAttempts, 2);
    expect(stored, Uint8List.fromList(validJpeg));
  });

  test('outdated async viewer selection is no longer current', () {
    expect(
      isCurrentScreenViewerSelection('participant-a', 'participant-b'),
      isFalse,
    );
    expect(
      isCurrentScreenViewerSelection('participant-b', 'participant-b'),
      isTrue,
    );
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
