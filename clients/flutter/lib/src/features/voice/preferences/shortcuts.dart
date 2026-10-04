import '../lifecycle/controller.dart';
import '../shortcuts/model.dart';

extension VoiceShortcutPreferences on VoiceController {
  Future<void> setVoiceShortcut(
    String action,
    VoiceShortcutBinding? value,
  ) async {
    if (action != 'microphone' && action != 'deafen') return;
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final previous = action == 'microphone'
        ? microphoneShortcut
        : deafenShortcut;
    final other = action == 'microphone' ? deafenShortcut : microphoneShortcut;
    if (value != null && !value.isValid) {
      audioActivationError = 'Назначьте сочетание с Ctrl, Alt, Shift или Meta и основной клавишей.';
      notifyListeners();
      return;
    }
    final conflict = value == null
        ? null
        : voiceShortcutConflict(value, other, pushToTalkKeyId);
    if (conflict != null) {
      audioActivationError = conflict == 'duplicate'
          ? 'Это сочетание уже назначено.'
          : conflict == 'ptt'
          ? 'Сочетание конфликтует с push-to-talk.'
          : conflict == 'search'
          ? 'Ctrl/Meta+K зарезервировано для поиска.'
          : 'Сочетание зарезервировано системой.';
      notifyListeners();
      return;
    }
    if (action == 'microphone')
      microphoneShortcut = value;
    else
      deafenShortcut = value;
    audioActivationError = null;
    try {
      if (audioPreferences == null)
        throw StateError('Preferences unavailable.');
      if (action == 'microphone') {
        await audioPreferences?.setMicrophoneShortcut(value);
      } else {
        await audioPreferences?.setDeafenShortcut(value);
      }
    } catch (cause) {
      if (!active(ticket, revision)) return;
      if (action == 'microphone')
        microphoneShortcut = previous;
      else
        deafenShortcut = previous;
      audioActivationError =
          'Не удалось сохранить сочетание: ${cause.runtimeType}.';
    }
    if (active(ticket, revision)) notifyListeners();
  }

  Future<void> resetVoiceShortcuts() async {
    final ticket = scope.capture();
    final revision = operationRevision;
    try {
      if (audioPreferences == null)
        throw StateError('Preferences unavailable.');
      await audioPreferences!.resetVoiceShortcuts();
      if (!active(ticket, revision)) return;
      microphoneShortcut = deafenShortcut = null;
      audioActivationError = null;
      cancelVoiceShortcuts();
    } catch (_) {
      if (!active(ticket, revision)) return;
      audioActivationError = 'Не удалось сбросить сочетания.';
    }
    notifyListeners();
  }
}
