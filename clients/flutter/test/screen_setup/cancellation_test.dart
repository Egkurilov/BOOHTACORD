import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/cancelled.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import '../screen_scope/fakes.dart';

class CancelledDriver extends DelayedScreenDriver {
  CancelledDriver(this.cause);
  final Object cause;
  @override
  Future<void> prepare(bool Function() active) async => throw cause;
}

void main() {
  test('system picker cancellation returns idle and never stops existing voice or publishes tracks', () async {
    for (final cause in [
      const ScreenCaptureCancelled(),
      PlatformException(code: 'USER_CANCELLED'),
    ]) {
      final room = FakeScreenRoom();
      final driver = CancelledDriver(cause);
      final owner = ScreenShareController(
        ApiClient(),
        SessionScope(),
        readRoom: () => room,
        voiceReady: () => true,
        driver: driver,
      );
      await owner.startScreenShare();
      expect(owner.phase, ScreenSharePhase.idle);
      expect(owner.error, isNull);
      expect(driver.published, 0);
      expect(driver.stopCalls, 0);
      expect(driver.backgroundDisableCalls, 1);
      expect(owner.activeTrack, isNull);
      expect(owner.readRoom(), same(room));
      owner.dispose();
      await owner.closing;
    }
  });
  test(
    'actual permission denial stays explicit without closing voice',
    () async {
      final room = FakeScreenRoom();
      final driver = CancelledDriver(
        PlatformException(code: 'PERMISSION_DENIED'),
      );
      final owner = ScreenShareController(
        ApiClient(),
        SessionScope(),
        readRoom: () => room,
        voiceReady: () => true,
        driver: driver,
      );
      await owner.startScreenShare();
      expect(owner.phase, ScreenSharePhase.error);
      expect(owner.error, isNotNull);
      expect(owner.readRoom(), same(room));
      expect(driver.stopCalls, 0);
      owner.dispose();
      await owner.closing;
    },
  );
}
