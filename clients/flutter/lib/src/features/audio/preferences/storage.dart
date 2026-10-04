part of 'state.dart';
extension AudioPreferenceStorage on AudioPreferences {
  void _load() {
    try {
      final raw = _storage?.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      microphone = MicrophoneSettings.fromJson(decoded);
      processing = AudioProcessingPreferences.fromJson(decoded['processing']);
      inputDeviceId = decoded['inputDeviceId'] as String?;
      outputDeviceId = decoded['outputDeviceId'] as String?;
      activationMode = decoded['activationMode'] == 'PTT' ? 'PTT' : 'VAD';
      pttKeyId = decoded['pttKeyId'] is int ? decoded['pttKeyId'] as int : null;
      pttKeyLabel = decoded['pttKeyLabel'] as String?;
      microphoneShortcut = _shortcut(decoded['microphoneShortcut']);
      deafenShortcut = _shortcut(decoded['deafenShortcut']);
    } catch (_) {}
  }

  VoiceShortcutBinding? _shortcut(Object? value) {
    try { return value == null ? null : VoiceShortcutBinding.fromJson(value); } catch (_) { return null; }
  }

  Future<void> _unavailable() => Future<void>.error(
    StateError('Audio preferences storage is unavailable.'),
  );

  Future<void> _save() {
    if (_storage == null) {
      return Future<void>.error(
        StateError('Audio preferences storage is unavailable.'),
      );
    }
    Future<void> write() async {
      final result = await _storage.setString(
        _key,
        jsonEncode({
          ...microphone.toJson(),
          'processing': processing.toJson(),
          'inputDeviceId': inputDeviceId,
          'outputDeviceId': outputDeviceId,
          'activationMode': activationMode,
          'pttKeyId': pttKeyId,
          'pttKeyLabel': pttKeyLabel,
          'microphoneShortcut': microphoneShortcut?.toJson(),
          'deafenShortcut': deafenShortcut?.toJson(),
        }),
      );
      if (result == false) {
        throw StateError('Audio preferences were not saved.');
      }
    }

    final next = _pendingWrite.then((_) => write());
    _pendingWrite = next.catchError((_) {});
    return next;
  }
}
