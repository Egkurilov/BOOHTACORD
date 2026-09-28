import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NativeNotificationPermission { granted, denied, unavailable }

abstract interface class NativeNotificationDriver {
  Future<void> initialize();
  Future<NativeNotificationPermission> permission();
  Future<NativeNotificationPermission> requestPermission();
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

abstract interface class NativeNotificationPreferences {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
}

class _SharedPreferencesNotificationStore
    implements NativeNotificationPreferences {
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get preferences =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<bool?> getBool(String key) => preferences.getBool(key);

  @override
  Future<void> setBool(String key, bool value) =>
      preferences.setBool(key, value);

  @override
  Future<List<String>?> getStringList(String key) =>
      preferences.getStringList(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      preferences.setStringList(key, value);
}

class FlutterLocalNotificationDriver implements NativeNotificationDriver {
  FlutterLocalNotificationDriver({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
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
  Future<NativeNotificationPermission> permission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled == null
          ? NativeNotificationPermission.unavailable
          : enabled
          ? NativeNotificationPermission.granted
          : NativeNotificationPermission.denied;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return enabled == null
          ? NativeNotificationPermission.unavailable
          : enabled.isEnabled
          ? NativeNotificationPermission.granted
          : NativeNotificationPermission.denied;
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return NativeNotificationPermission.granted;
    }
    return NativeNotificationPermission.unavailable;
  }

  @override
  Future<NativeNotificationPermission> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _plugin
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
      final enabled = await _plugin
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
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
  }
}

String? notificationBodyForUnreadIncrease({
  required String kind,
  required int? previousUnread,
  required int? currentUnread,
}) {
  if (previousUnread == null ||
      currentUnread == null ||
      currentUnread <= previousUnread) {
    return null;
  }
  return switch (kind) {
    'message.created' => 'Новое сообщение в канале.',
    'direct_message.message_created' => 'Новое личное сообщение.',
    _ => null,
  };
}

class NativeNotificationService {
  NativeNotificationService({
    NativeNotificationDriver? driver,
    NativeNotificationPreferences? preferences,
  }) : _driver = driver ?? FlutterLocalNotificationDriver(),
       _preferences = preferences ?? _SharedPreferencesNotificationStore();

  final NativeNotificationDriver _driver;
  final NativeNotificationPreferences _preferences;
  String? _accountId;
  bool _initialized = false;
  bool enabled = false;
  NativeNotificationPermission permission =
      NativeNotificationPermission.unavailable;
  String? error;
  final Set<String> _deliveriesInFlight = <String>{};

  bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isMacOS || Platform.isWindows);

  Future<void> initialize() async {
    if (!supported || _initialized) return;
    try {
      await _driver.initialize();
      _initialized = true;
      await refreshStatus();
    } catch (cause) {
      error = _message(cause);
      permission = NativeNotificationPermission.unavailable;
    }
  }

  Future<void> useAccount(String? accountId) async {
    _accountId = accountId;
    enabled = false;
    error = null;
    if (accountId == null) return;
    await initialize();
    if (!_initialized) return;
    try {
      enabled = await _preferences.getBool(_enabledKey(accountId)) ?? false;
      await refreshStatus();
    } catch (cause) {
      error = _message(cause);
      enabled = false;
    }
  }

  Future<void> refreshStatus() async {
    if (!_initialized) return;
    try {
      permission = await _driver.permission();
    } catch (cause) {
      permission = NativeNotificationPermission.unavailable;
      error = _message(cause);
    }
  }

  Future<bool> enable() async {
    final accountId = _accountId;
    if (accountId == null || !_initialized) return false;
    error = null;
    try {
      permission = permission == NativeNotificationPermission.granted
          ? permission
          : await _driver.requestPermission();
      enabled = permission == NativeNotificationPermission.granted;
      await _preferences.setBool(_enabledKey(accountId), enabled);
      return enabled;
    } catch (cause) {
      error = _message(cause);
      enabled = false;
      return false;
    }
  }

  Future<void> disable() async {
    final accountId = _accountId;
    enabled = false;
    error = null;
    if (accountId != null) {
      await _preferences.setBool(_enabledKey(accountId), false);
    }
  }

  Future<void> deliver({
    required String eventId,
    required String body,
    required bool appIsForeground,
  }) async {
    final accountId = _accountId;
    if (accountId == null ||
        !_initialized ||
        !enabled ||
        appIsForeground ||
        permission != NativeNotificationPermission.granted) {
      return;
    }
    if (!_deliveriesInFlight.add(eventId)) return;
    final key = _seenKey(accountId);
    try {
      final seen = await _preferences.getStringList(key) ?? const <String>[];
      if (seen.contains(eventId)) return;
      await _driver.show(
        id: _notificationId(eventId),
        title: 'Voice Platform',
        body: body,
      );
      await _preferences.setStringList(
        key,
        [...seen, eventId].takeLast(512).toList(),
      );
    } catch (cause) {
      error = _message(cause);
    } finally {
      _deliveriesInFlight.remove(eventId);
    }
  }

  static String _enabledKey(String accountId) =>
      'boohtacord:notification:$accountId:enabled';

  static String _seenKey(String accountId) =>
      'boohtacord:notification:$accountId:seen';

  static int _notificationId(String eventId) {
    final normalized = eventId.replaceAll('-', '');
    final prefix = normalized.length >= 8
        ? normalized.substring(0, 8)
        : normalized;
    return (int.tryParse(prefix, radix: 16) ?? eventId.hashCode) & 0x7fffffff;
  }

  static String _message(Object cause) {
    if (cause is PlatformException && cause.code == 'invalid_icon') {
      return 'Не удалось подготовить значок системного уведомления.';
    }
    if (cause is Exception && cause.toString().startsWith('Exception: ')) {
      return cause.toString().substring('Exception: '.length);
    }
    return cause.toString();
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) => skip(length > count ? length - count : 0);
}
