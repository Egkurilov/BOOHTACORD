import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'fakes.dart';

void main() {
  test(
    'capture arriving after stop is discarded without publication',
    () async {
      final driver = DelayedScreenDriver();
      final room = FakeScreenRoom();
      final owner = ScreenShareController(
        ApiClient(),
        SessionScope(),
        readRoom: () => room,
        voiceReady: () => true,
        driver: driver,
      );
      addTearDown(owner.dispose);
      final start = owner.startScreenShare();
      await Future<void>.delayed(Duration.zero);
      final stop = owner.stopScreenShare();
      final track = FakeScreenTrack();
      driver.captured.complete(track);
      await Future.wait([start, stop]);
      expect(driver.published, 0);
      expect(driver.stopped, contains(track));
      expect(owner.phase, ScreenSharePhase.idle);
      expect(owner.error, isNull);
    },
  );
  test('logout during publication removes only that attempt track', () async {
    final scope = SessionScope();
    final driver = DelayedScreenDriver()..publication = Completer<void>();
    final room = FakeScreenRoom();
    final owner = ScreenShareController(
      ApiClient(),
      scope,
      readRoom: () => room,
      voiceReady: () => true,
      driver: driver,
    );
    addTearDown(owner.dispose);
    final track = FakeScreenTrack();
    driver.captured.complete(track);
    final start = owner.startScreenShare();
    await Future<void>.delayed(Duration.zero);
    expect(driver.published, 1);
    scope.close();
    final stop = owner.stopScreenShare();
    driver.publication!.complete();
    await Future.wait([start, stop]);
    expect(driver.removed, [track]);
    expect(owner.phase, ScreenSharePhase.idle);
    expect(owner.error, isNull);
  });
}
