import 'dart:async';

import 'package:boohtacord_desktop/src/services/native_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test(
    'late account preference cannot enable notifications after logout',
    () async {
      final prefs = NotificationPreferencesFake()
        ..enabledRead = Completer<bool?>();
      final service = NativeNotificationService(
        driver: NotificationDriverFake(),
        preferences: prefs,
        supportedOnCurrentPlatform: true,
      );
      final loading = service.useAccount('account-a');
      await prefs.started.future;
      await service.useAccount(null);
      prefs.enabledRead!.complete(true);
      await loading;
      expect(service.enabled, isFalse);
    },
  );

  test('late dedup read cannot deliver an old account notification', () async {
    final prefs = NotificationPreferencesFake()
      ..seenRead = Completer<List<String>?>();
    final driver = NotificationDriverFake();
    final service = NativeNotificationService(
      driver: driver,
      preferences: prefs,
      supportedOnCurrentPlatform: true,
    );
    await service.useAccount('account-a');
    await service.enable();
    final delivery = service.deliver(
      eventId: 'event',
      body: 'Generic notification',
      appIsForeground: false,
    );
    await prefs.started.future;
    await service.useAccount(null);
    prefs.seenRead!.complete([]);
    await delivery;
    expect(driver.shown, 0);
  });
}
