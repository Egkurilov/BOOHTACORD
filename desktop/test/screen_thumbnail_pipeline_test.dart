import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validJpeg = [0xff, 0xd8, 0xff, 0xd9];

  test(
    'reports capture failure without attempting encode or publish',
    () async {
      var encoded = false;
      var published = false;

      final result = await publishScreenThumbnailFrame(
        capture: () async => throw StateError('capture failed'),
        encode: (_) async {
          encoded = true;
          return Uint8List.fromList(validJpeg);
        },
        storeLocally: (_) {},
        publish: (_) async => published = true,
        isActive: () => true,
      );

      expect(result, ScreenThumbnailPublishResult.captureFailed);
      expect(encoded, isFalse);
      expect(published, isFalse);
    },
  );

  test('reports encoding failure without publishing', () async {
    var published = false;

    final result = await publishScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => throw StateError('encode failed'),
      storeLocally: (_) {},
      publish: (_) async => published = true,
      isActive: () => true,
    );

    expect(result, ScreenThumbnailPublishResult.encodingFailed);
    expect(published, isFalse);
  });

  test('rejects invalid JPEG before local storage or publish', () async {
    var stored = false;
    var published = false;

    final result = await publishScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => Uint8List.fromList([1, 2, 3]),
      storeLocally: (_) => stored = true,
      publish: (_) async => published = true,
      isActive: () => true,
    );

    expect(result, ScreenThumbnailPublishResult.invalidThumbnail);
    expect(stored, isFalse);
    expect(published, isFalse);
  });

  test('stores and publishes a valid bounded thumbnail', () async {
    final thumbnail = Uint8List.fromList(validJpeg);
    Uint8List? stored;
    Uint8List? published;

    final result = await publishScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => thumbnail,
      storeLocally: (bytes) => stored = bytes,
      publish: (bytes) async => published = bytes,
      isActive: () => true,
    );

    expect(result, ScreenThumbnailPublishResult.published);
    expect(stored, same(thumbnail));
    expect(published, same(thumbnail));
  });

  test('does not store or publish a frame after sharing stops', () async {
    var active = true;
    var stored = false;
    var published = false;

    final result = await publishScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async {
        active = false;
        return Uint8List.fromList(validJpeg);
      },
      storeLocally: (_) => stored = true,
      publish: (_) async => published = true,
      isActive: () => active,
    );

    expect(result, ScreenThumbnailPublishResult.cancelled);
    expect(stored, isFalse);
    expect(published, isFalse);
  });

  test('reports publish failure after keeping local preview', () async {
    final thumbnail = Uint8List.fromList(validJpeg);
    Uint8List? stored;

    final result = await publishScreenThumbnailFrame(
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => thumbnail,
      storeLocally: (bytes) => stored = bytes,
      publish: (_) async => throw StateError('publish failed'),
      isActive: () => true,
    );

    expect(result, ScreenThumbnailPublishResult.publishFailed);
    expect(stored, same(thumbnail));
  });
}
