import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import '../settings/model.dart';

class VoiceOverlayPreferences {
  VoiceOverlayPreferences(this._storage, this.accountId, {bool? onlySpeakers})
    : onlySpeakers =
          onlySpeakers ?? _storage?.getBool(_keyFor(accountId)) ?? false;

  final SharedPreferences? _storage;
  final String accountId;
  bool onlySpeakers;
  OverlayConfiguration get configuration {
    try {
      final raw = _storage?.getString('voice-overlay:v2:$accountId:settings');
      if (raw != null) {
        return OverlayConfiguration.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return const OverlayConfiguration();
  }

  Future<bool> saveConfiguration(OverlayConfiguration value) async {
    try {
      return await _storage?.setString(
            'voice-overlay:v2:$accountId:settings',
            jsonEncode(value.toJson()),
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static String _keyFor(String accountId) =>
      'voice-overlay:v1:$accountId:only-speakers';

  static Future<VoiceOverlayPreferences> open(String accountId) async {
    SharedPreferences? storage;
    try {
      storage = await SharedPreferences.getInstance();
    } catch (_) {}
    return VoiceOverlayPreferences(storage, accountId);
  }

  Future<bool> setOnlySpeakers(bool value) async {
    if (_storage == null) return false;
    try {
      final saved = await _storage.setBool(_keyFor(accountId), value);
      if (saved) onlySpeakers = value;
      return saved;
    } catch (_) {}
    return false;
  }
}
