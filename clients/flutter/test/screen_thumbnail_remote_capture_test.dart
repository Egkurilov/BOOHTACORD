import 'dart:async';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/screen_thumbnail_remote_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validJpeg = [0xff, 0xd8, 0xff, 0xd9];

  test('captures only after the selected receiver decoded a frame', () async {
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

  test('stops before encoding a frame after selection becomes inactive', () async {
    final captureDone = Completer<Uint8List>();
    var active = true;
    var encodes = 0;
    final result = captureRemoteScreenThumbnail(
      hasDecodedFrames: () async => true,
      capture: () => captureDone.future,
      encode: (_) async {
        encodes++;
        return Uint8List.fromList(validJpeg);
      },
      isActive: () => active,
      wait: (_) async {},
    );

    await Future<void>.delayed(Duration.zero);
    active = false;
    captureDone.complete(Uint8List.fromList([1]));

    expect(await result, isNull);
    expect(encodes, 0);
  });

  test('bounds selected receiver polling when no frame is decoded', () async {
    var reads = 0;
    var waits = 0;
    final result = await captureRemoteScreenThumbnail(
      hasDecodedFrames: () async {
        reads++;
        return false;
      },
      capture: () async => Uint8List.fromList([1]),
      encode: (_) async => Uint8List.fromList(validJpeg),
      isActive: () => true,
      wait: (_) async => waits++,
      maxAttempts: 4,
    );

    expect(result, isNull);
    expect(reads, 4);
    expect(waits, 3);
  });
}
