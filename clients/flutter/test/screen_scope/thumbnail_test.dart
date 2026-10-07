import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/thumbnail_state/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/client.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/uploader.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:http/testing.dart';

import 'fakes.dart';

void main() {
  test('a replaced track cannot publish a pending encoded thumbnail', () async {
    final oldTrack = FakeScreenTrack();
    final newTrack = FakeScreenTrack();
    final pending = Completer<Uint8List?>();
    final room = FakeScreenRoom();
    final thumbnails = <String, Uint8List>{};
    final previewApi = ApiClient(
      client: MockClient((request) async {
        throw StateError('unexpected preview request: ${request.method}');
      }),
    );
    final owner = ScreenThumbnailController(
      SessionScope(),
      readRoom: () => room,
      isSharing: () => true,
      thumbnails: thumbnails,
      queue: ScreenThumbnailCaptureQueue(),
      changed: () {},
      previewUploader: LatestScreenPreviewUploader(
        ScreenPreviewClient(previewApi.transport),
      ),
      capture: (track) async =>
          Uint8List.fromList([identical(track, oldTrack) ? 1 : 2]),
      encode: (frame) async => frame.first == 1
          ? pending.future
          : Uint8List.fromList([0xff, 0xd8, 2, 0xff, 0xd9]),
    );
    addTearDown(() async {
      await owner.stop();
      previewApi.transport.raw.close();
    });
    owner.start(room, oldTrack);
    await Future<void>.delayed(Duration.zero);
    owner.start(room, newTrack);
    await Future<void>.delayed(Duration.zero);
    expect(thumbnails['local']![2], 2);
    pending.complete(Uint8List.fromList([0xff, 0xd8, 1, 0xff, 0xd9]));
    await Future<void>.delayed(Duration.zero);
    expect(thumbnails['local']![2], 2);
  });
}
