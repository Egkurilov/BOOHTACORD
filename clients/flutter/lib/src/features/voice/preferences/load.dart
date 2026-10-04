import '../../../services/audio_preferences.dart';
import '../microphone/shortcut.dart';
import '../lifecycle/controller.dart';

extension VoicePreferencesLoad on VoiceController {
  Future<void> loadAudioPreferences(String accountId) async {
    final ticket = scope.capture();
    final preferences = await AudioPreferences.open(accountId);
    if (!ticket.isActive || readUser()?.accountId != accountId) return;
    audioPreferences = preferences;
    if (!preferences.persistent) {
      audioSettingsError = 'Не удалось открыть хранилище настроек аудио.';
    }
    selectedAudioInputId = preferences.inputDeviceId;
    selectedAudioOutputId = preferences.outputDeviceId;
    audioProcessing = preferences.processing;
    audioActivationMode = preferences.activationMode == 'PTT'
        ? AudioActivationMode.ptt
        : AudioActivationMode.vad;
    audio.microphoneVad = audioActivationMode == AudioActivationMode.vad;
    pushToTalkKeyId = preferences.pttKeyId;
    pushToTalkKeyLabel = preferences.pttKeyLabel;
    microphoneShortcut =
        preferences.microphoneShortcut?.isValid == true &&
            voiceShortcutConflict(
                  preferences.microphoneShortcut!,
                  null,
                  pushToTalkKeyId,
                ) ==
                null
        ? preferences.microphoneShortcut
        : null;
    deafenShortcut =
        preferences.deafenShortcut?.isValid == true &&
            voiceShortcutConflict(
                  preferences.deafenShortcut!,
                  microphoneShortcut,
                  pushToTalkKeyId,
                ) ==
                null
        ? preferences.deafenShortcut
        : null;
    cancelVoiceShortcuts(release: true);
    audioActivationError =
        audioActivationMode == AudioActivationMode.ptt &&
            pushToTalkKeyId == null &&
            !usesTouchPushToTalk
        ? 'Назначьте клавишу для push-to-talk.'
        : null;
  }

  Future<void> setPushToTalkKey(int? keyId, String? label) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final previousId = pushToTalkKeyId;
    final previousLabel = pushToTalkKeyLabel;
    if (keyId != null &&
        [microphoneShortcut, deafenShortcut].any(
          (binding) =>
              binding != null &&
              voiceShortcutConflict(binding, null, keyId) == 'ptt',
        )) {
      audioActivationError = 'Эта клавиша уже назначена для другого действия.';
      notifyListeners();
      return;
    }
    pushToTalkKeyId = keyId;
    pushToTalkKeyLabel = keyId == null ? null : label;
    audioActivationError = null;
    try {
      await audioPreferences?.setPttKey(pushToTalkKeyId, pushToTalkKeyLabel);
    } catch (cause) {
      if (!active(ticket, revision)) return;
      pushToTalkKeyId = previousId;
      pushToTalkKeyLabel = previousLabel;
      audioActivationError =
          'Не удалось сохранить клавишу PTT: ${cause.runtimeType}.';
    }
    if (active(ticket, revision)) notifyListeners();
  }
}
