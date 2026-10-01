import 'package:shared_preferences/shared_preferences.dart';

import 'contracts.dart';

class SharedPreferencesNotificationStore
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
