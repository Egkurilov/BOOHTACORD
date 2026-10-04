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
    pushToTalkKeyId = preferences.pttKeyId;
    pushToTalkKeyLabel = preferences.pttKeyLabel;
    microphoneShortcut = preferences.microphoneShortcut?.isValid == true
        ? preferences.microphoneShortcut
        : null;
    deafenShortcut = preferences.deafenShortcut?.isValid == true
        ? preferences.deafenShortcut
        : null;
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
        (microphoneShortcut?.keyId == keyId || deafenShortcut?.keyId == keyId)) {
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

  Future<void> setVoiceShortcut(String action, VoiceShortcutBinding? value) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final previous = action == 'microphone' ? microphoneShortcut : deafenShortcut;
    final other = action == 'microphone' ? deafenShortcut : microphoneShortcut;
    if (value != null && !value.isValid) {
      audioActivationError = 'Назначьте сочетание с Ctrl, Alt, Shift или Meta и основной клавишей.';
      notifyListeners();
      return;
    }
    final conflict = value == null ? null : voiceShortcutConflict(value, other, pushToTalkKeyId);
    if (conflict != null) {
      audioActivationError = conflict == 'duplicate'
          ? 'Это сочетание уже назначено.'
          : conflict == 'ptt'
          ? 'Сочетание конфликтует с push-to-talk.'
          : 'Ctrl/Meta+K зарезервировано для поиска.';
      notifyListeners();
      return;
    }
    if (action == 'microphone') microphoneShortcut = value;
    else deafenShortcut = value;
    audioActivationError = null;
    try {
      if (action == 'microphone') {
        await audioPreferences?.setMicrophoneShortcut(value);
      } else {
        await audioPreferences?.setDeafenShortcut(value);
      }
    } catch (cause) {
      if (!active(ticket, revision)) return;
      if (action == 'microphone') microphoneShortcut = previous;
      else deafenShortcut = previous;
      audioActivationError = 'Не удалось сохранить сочетание: ${cause.runtimeType}.';
    }
    if (active(ticket, revision)) notifyListeners();
  }
}
