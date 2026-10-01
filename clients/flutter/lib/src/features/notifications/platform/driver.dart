import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../lifecycle/contracts.dart';

import 'permission.dart';
import 'request_permission.dart' as requests;

class FlutterLocalNotificationDriver implements NativeNotificationDriver {
  FlutterLocalNotificationDriver({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'BOOHTACORD',
          appUserModelId: 'ru.boohtacord.app',
          guid: 'd6719dc8-b178-4bd4-9c20-e3a4c8eff730',
        ),
      ),
    );
  }

  @override
  Future<NativeNotificationPermission> permission() => readPermission(_plugin);
  @override
  Future<NativeNotificationPermission> requestPermission() =>
      requests.requestPermission(_plugin);

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          'Сообщения',
          channelDescription: 'Новые непрочитанные сообщения',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
  }
}
