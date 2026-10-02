import 'package:shared_preferences/shared_preferences.dart';

class UpdatePreferences {
  UpdatePreferences([SharedPreferencesAsync? preferences]) : _preferences = preferences;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _storage => _preferences ??= SharedPreferencesAsync();

  String _key(String origin, String platform, String release, String priority) => 'client-update:$origin:boohtacord:$platform:direct:stable:$release:$priority';

  Future<bool> isSnoozed(String origin, String platform, String release, String priority) async {
    final until = await _storage.getInt(_key(origin, platform, release, priority)) ?? 0;
    return until > DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> snooze(String origin, String platform, String release, String priority) {
    final duration = priority == 'important' ? const Duration(minutes:15) : const Duration(hours:2);
    return _storage.setInt(_key(origin, platform, release, priority), DateTime.now().add(duration).millisecondsSinceEpoch);
  }
}
