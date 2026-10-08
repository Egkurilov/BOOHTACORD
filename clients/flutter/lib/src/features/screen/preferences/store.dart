import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/quality.dart';

class ScreenQualityPreferences {
  ScreenQualityPreferences(String baseUrl, String accountId, {
    Future<SharedPreferences> Function()? open, bool Function()? current,
  }) : key = 'screen-quality:v1:${Uri.encodeComponent(Uri.parse(baseUrl).origin)}:${Uri.encodeComponent(accountId)}',
       _open = open ?? SharedPreferences.getInstance, _current = current ?? (() => true);
  final String key;
  final Future<SharedPreferences> Function() _open;
  final bool Function() _current;
  bool get isCurrent => _current();

  Future<ScreenShareQuality?> read() async {
    try {
      if (!_current()) return null;
      final preferences = await _open();
      if (!_current()) return null;
      final value = preferences.getString(key);
      if (value == null) return null;
      final decoded = _decode(value);
      if (decoded == null) return null;
      final match = RegExp(r'^P(720|1080|1440)_(15|30|60)$').firstMatch(decoded);
      return match == null ? null : ScreenShareQuality(
        resolution: int.parse(match[1]!), frameRate: int.parse(match[2]!));
    } catch (_) { return null; }
  }

  Future<bool> save(ScreenShareQuality quality) async {
    try {
      if (!_current()) return false;
      quality.maxBitrateBps; // Validate against the existing typed profile catalog.
      final preferences = await _open();
      if (!_current()) return false;
      final previous = preferences.getString(key);
      if (previous != null && previous.startsWith('{')) {
        final envelope = jsonDecode(previous);
        if (envelope is Map && envelope['schema_version'] != 1) return false;
      }
      return await preferences.setString(key, jsonEncode({
        'schema_version': 1, 'profile_id': 'P${quality.resolution}_${quality.frameRate}',
      }));
    } catch (_) { return false; }
  }

  String? _decode(String value) {
    if (!value.startsWith('{')) return value;
    final envelope = jsonDecode(value);
    if (envelope is! Map || envelope['schema_version'] != 1 ||
        envelope['profile_id'] is! String) { return null; }
    return envelope['profile_id'] as String;
  }
}
