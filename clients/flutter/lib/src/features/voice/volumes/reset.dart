import '../../../services/voice_volume_preferences.dart';
import '../lifecycle/controller.dart';
extension VoiceVolumeReset on VoiceController {
  void volumePreferenceOutcome(String outcome) {
    voiceVolumeWarning = switch (outcome) {
      'fallback' => 'Настройки громкости недоступны; изменения действуют до выхода.',
      'error' => 'Не удалось применить громкость. Разговор можно продолжить.',
      _ => null,
    };
    try { volumeTelemetry.submit(outcome); } catch (_) {}
  }
  Future<void> flushVoiceVolumes() async {
    final preferences = voiceVolumePreferences;
    if (preferences == null) return;
    try { await preferences.flush().timeout(const Duration(seconds: 1)); }
    catch (_) {
      if (!disposed && identical(preferences, voiceVolumePreferences)) {
        volumePreferenceOutcome('fallback'); notifyListeners();
      }
    }
  }
  Future<void> resetAudioVolumes() async {
    final ticket = scope.capture();
    final revision = operationRevision;
    final account = readUser();
    if (account == null || !active(ticket, revision)) return;
    var preferences = voiceVolumePreferences;
    if (preferences == null || !preferences.belongsTo(account.accountId, api.baseUrl)) {
      await flushVoiceVolumes();
      if (!active(ticket, revision)) return;
      preferences = await VoiceVolumePreferences.open(account.accountId, origin: api.baseUrl);
      if (!active(ticket, revision) || readUser()?.accountId != account.accountId ||
          !preferences.belongsTo(account.accountId, api.baseUrl)) return;
      voiceVolumePreferences = preferences;
    }
    transientScreenShareVolumes.clear();
    final reset = preferences.reset();
    notifyListeners();
    try {
      final currentRoom = room;
      await Future.wait([reset, if (currentRoom != null) applySavedVoiceVolumes(currentRoom)]);
      if (active(ticket, revision)) volumePreferenceOutcome(preferences.status);
    } catch (_) {
      if (active(ticket, revision)) volumePreferenceOutcome(preferences.status == 'fallback' ? 'fallback' : 'error');
    }
    if (active(ticket, revision)) notifyListeners();
  }
}
