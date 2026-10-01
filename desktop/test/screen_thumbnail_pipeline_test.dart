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

  test(
    'stops the bounded receiver capture when the stream becomes inactive',
    () async {
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
    },
  );

  test(
    'gives up after the preview deadline when no video frame is decoded',
    () async {
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
    },
  );

  test(
    'serializes captures that share the native temporary-frame file',
    () async {
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
    },
  );

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

  test(
    'serializes remote preview subscriptions and deduplicates a publication',
    () async {
      final queue = ScreenPreviewSubscriptionQueue();
      final firstGate = Completer<void>();
      final order = <String>[];

      final first = queue.enqueue('track-1', () async {
        order.add('start-1');
        await firstGate.future;
        order.add('end-1');
      });
      final duplicate = queue.enqueue('track-1', () async {
        order.add('duplicate');
      });
      final second = queue.enqueue('track-2', () async {
        order.add('start-2');
      });

      await Future<void>.delayed(Duration.zero);
      expect(order, ['start-1']);
      firstGate.complete();
      await Future.wait([first, duplicate, second]);

      expect(order, ['start-1', 'end-1', 'start-2']);
    },
  );

  test(
    'temporary preview subscription is released after a successful capture',
    () async {
      final events = <String>[];

      final result = await withTemporaryScreenPreviewSubscription<String>(
        subscribe: () async => events.add('subscribe'),
        action: () async {
          events.add('capture');
          return 'thumbnail';
        },
        unsubscribe: () async => events.add('unsubscribe'),
        keepSubscribed: () => false,
      );

      expect(result, 'thumbnail');
      expect(events, ['subscribe', 'capture', 'unsubscribe']);
    },
  );

  test(
    'temporary preview subscription is released when capture fails',
    () async {
      final events = <String>[];

      await expectLater(
        withTemporaryScreenPreviewSubscription<void>(
          subscribe: () async => events.add('subscribe'),
          action: () async => throw StateError('capture failed'),
          unsubscribe: () async => events.add('unsubscribe'),
          keepSubscribed: () => false,
        ),
        throwsStateError,
      );

      expect(events, ['subscribe', 'unsubscribe']);
    },
  );

  test('selected viewer retains subscription after preview action', () async {
    final events = <String>[];

    await withTemporaryScreenPreviewSubscription<void>(
      subscribe: () async => events.add('subscribe'),
      action: () async => events.add('capture'),
      unsubscribe: () async => events.add('unsubscribe'),
      keepSubscribed: () => true,
    );

    expect(events, ['subscribe', 'capture']);
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
    'a closed remote preview queue skips publications that have not started',
    () async {
      final queue = ScreenPreviewSubscriptionQueue();
      final firstGate = Completer<void>();
      var secondStarted = false;
      final first = queue.enqueue('track-1', () => firstGate.future);
      final second = queue.enqueue('track-2', () async => secondStarted = true);

      await Future<void>.delayed(Duration.zero);
      queue.close();
      firstGate.complete();
      await Future.wait([first, second]);

      expect(secondStarted, isFalse);
    },
  );

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
