part of 'state.dart';

extension AudioShortcutStorage on AudioPreferences {
  Future<void> _replaceShortcuts(
    VoiceShortcutBinding? microphone,
    VoiceShortcutBinding? deafen,
  ) async {
    if (_storage == null) return _unavailable();
    final previousMicrophone = microphoneShortcut,
        previousDeafen = deafenShortcut;
    microphoneShortcut = microphone;
    deafenShortcut = deafen;
    try {
      await _save();
    } catch (_) {
      if (microphoneShortcut == microphone && deafenShortcut == deafen) {
        microphoneShortcut = previousMicrophone;
        deafenShortcut = previousDeafen;
      }
      rethrow;
    }
  }
}
