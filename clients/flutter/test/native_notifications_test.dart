import 'package:boohtacord_desktop/src/services/native_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'only emits generic notification copy when addressed unread increases',
    () {
      expect(
        notificationBodyForUnreadIncrease(
          kind: 'message.created',
          previousUnread: 2,
          currentUnread: 3,
        ),
        'Новое сообщение в канале.',
      );
      expect(
        notificationBodyForUnreadIncrease(
          kind: 'direct_message.message_created',
          previousUnread: 0,
          currentUnread: 1,
        ),
        'Новое личное сообщение.',
      );
      expect(
        notificationBodyForUnreadIncrease(
          kind: 'direct_message.message_created',
          previousUnread: 1,
          currentUnread: 1,
        ),
        isNull,
      );
      expect(
        notificationBodyForUnreadIncrease(
          kind: 'message.updated',
          previousUnread: 0,
          currentUnread: 1,
        ),
        isNull,
      );
    },
  );

  test('unsupported platform keeps notification delivery disabled', () async {
    final driver = _FakeNotificationDriver();
    final service = NativeNotificationService(
      driver: driver,
      preferences: _MemoryNotificationPreferences(),
      supportedOnCurrentPlatform: false,
    );
    await service.initialize();
    await service.useAccount('account-a');
    expect(await service.enable(), isFalse);
    expect(service.permission, NativeNotificationPermission.unavailable);
    expect(driver.permissionRequests, 0);
  });

  test(
    'notifies only when hidden, enabled, and once per event/account',
    () async {
      final driver = _FakeNotificationDriver();
      final service = NativeNotificationService(
        driver: driver,
        preferences: _MemoryNotificationPreferences(),
        supportedOnCurrentPlatform: true,
      );
      await service.initialize();
      await service.useAccount('account-a');
      expect(await service.enable(), isTrue);

      await service.deliver(
        eventId: '10000000-0000-4000-8000-000000000001',
        body: 'Новое личное сообщение.',
        appIsForeground: true,
      );
      await Future.wait([
        service.deliver(
          eventId: '10000000-0000-4000-8000-000000000001',
          body: 'Новое личное сообщение.',
          appIsForeground: false,
        ),
        service.deliver(
          eventId: '10000000-0000-4000-8000-000000000001',
          body: 'Новое личное сообщение.',
          appIsForeground: false,
        ),
      ]);

      expect(driver.shown, hasLength(1));
      expect(driver.shown.single.title, 'BOOHTACORD');
      expect(driver.shown.single.body, 'Новое личное сообщение.');
      expect(driver.shown.single.body, isNot(contains('секрет')));

      await service.useAccount('account-b');
      expect(service.enabled, isFalse);
      await service.deliver(
        eventId: '10000000-0000-4000-8000-000000000001',
        body: 'Новое сообщение в канале.',
        appIsForeground: false,
      );
      expect(driver.shown, hasLength(1));
    },
  );

  test('does not persist enabled state when OS permission is denied', () async {
    final driver = _FakeNotificationDriver()
      ..currentPermission = NativeNotificationPermission.denied
      ..nextPermission = NativeNotificationPermission.denied;
    final service = NativeNotificationService(
      driver: driver,
      preferences: _MemoryNotificationPreferences(),
      supportedOnCurrentPlatform: true,
    );
    await service.initialize();
    await service.useAccount('account-a');

    expect(await service.enable(), isFalse);
    expect(service.enabled, isFalse);
    expect(service.permission, NativeNotificationPermission.denied);
    expect(driver.permissionRequests, 1);
  });

  test(
    'explains an invalid Android notification icon without plugin details',
    () async {
      final driver = _FakeNotificationDriver()
        ..initializationFailure = PlatformException(
          code: 'invalid_icon',
          message: 'ic_launcher drawable is missing',
        );
      final service = NativeNotificationService(
        driver: driver,
        preferences: _MemoryNotificationPreferences(),
        supportedOnCurrentPlatform: true,
      );

      await service.initialize();

      expect(service.permission, NativeNotificationPermission.unavailable);
      expect(
        service.error,
        'Не удалось подготовить значок системного уведомления.',
      );
    },
  );
}

class _MemoryNotificationPreferences implements NativeNotificationPreferences {
  final values = <String, Object>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<List<String>?> getStringList(String key) async =>
      (values[key] as List<String>?)?.toList();

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      values[key] = value.toList();
}

class _FakeNotificationDriver implements NativeNotificationDriver {
  NativeNotificationPermission currentPermission =
      NativeNotificationPermission.granted;
  NativeNotificationPermission nextPermission =
      NativeNotificationPermission.granted;
  int permissionRequests = 0;
  Object? initializationFailure;
  final shown = <({int id, String title, String body})>[];

  @override
  Future<void> initialize() async {
    if (initializationFailure case final failure?) throw failure;
  }

  @override
  Future<NativeNotificationPermission> permission() async => currentPermission;

  @override
  Future<NativeNotificationPermission> requestPermission() async {
    permissionRequests++;
    currentPermission = nextPermission;
    return currentPermission;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add((id: id, title: title, body: body));
  }
}
