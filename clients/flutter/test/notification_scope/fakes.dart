import 'dart:async';

import 'package:boohtacord_desktop/src/services/native_notifications.dart';

class NotificationDriverFake implements NativeNotificationDriver {
  int shown = 0;
  @override
  Future<void> initialize() async {}
  @override
  Future<NativeNotificationPermission> permission() async =>
      NativeNotificationPermission.granted;
  @override
  Future<NativeNotificationPermission> requestPermission() => permission();
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shown++;
  }
}

class NotificationPreferencesFake implements NativeNotificationPreferences {
  Completer<bool?>? enabledRead;
  Completer<List<String>?>? seenRead;
  final started = Completer<void>();
  @override
  Future<bool?> getBool(String key) {
    if (enabledRead != null) {
      if (!started.isCompleted) started.complete();
      return enabledRead!.future;
    }
    return Future.value(false);
  }

  @override
  Future<void> setBool(String key, bool value) async {}
  @override
  Future<List<String>?> getStringList(String key) {
    if (!started.isCompleted) started.complete();
    return seenRead?.future ?? Future.value([]);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {}
}
