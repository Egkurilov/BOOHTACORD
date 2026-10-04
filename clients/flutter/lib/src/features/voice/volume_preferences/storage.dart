part of 'state.dart';
extension _VolumeStorage on VoiceVolumePreferences {
  void _load() {
    if (_storage == null || _origin.isEmpty) { status = 'fallback'; return; }
    try {
      final raw = _storage.getString(key);
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is! Map || value['version'] != 2 || value['volumes'] is! Map) throw const FormatException();
      final volumes = value['volumes'] as Map;
      for (final entry in volumes.entries) {
        if (entry.key is String) _values[entry.key as String] = VoiceLevels.decode(entry.value);
      }
    } catch (_) { _values.clear(); status = 'fallback'; }
  }
}
