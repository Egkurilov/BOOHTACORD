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
