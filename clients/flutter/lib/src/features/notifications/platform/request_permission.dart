import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../lifecycle/contracts.dart';

Future<NativeNotificationPermission> requestPermission(
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final enabled = await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
    return enabled == null
        ? NativeNotificationPermission.unavailable
        : enabled
        ? NativeNotificationPermission.granted
        : NativeNotificationPermission.denied;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    final enabled = await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return enabled == null
        ? NativeNotificationPermission.unavailable
        : enabled
        ? NativeNotificationPermission.granted
        : NativeNotificationPermission.denied;
  }
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    final enabled = await plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true);
    return enabled == null
        ? NativeNotificationPermission.unavailable
        : enabled
        ? NativeNotificationPermission.granted
        : NativeNotificationPermission.denied;
  }
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return NativeNotificationPermission.granted;
  }
  return NativeNotificationPermission.unavailable;
}
