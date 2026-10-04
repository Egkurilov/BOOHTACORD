import '../lifecycle/controller.dart';

final _running = Expando<Object>();
final _cancelled = Expando<Object>();

extension VoiceShortcutExecution on VoiceController {
  void cancelVoiceShortcuts({bool release = false}) {
    _cancelled[this] = _running[this];
    if (release) _running[this] = null;
    voiceShortcutStatus = null;
  }

  Future<String> runVoiceShortcut(String action) async {
    if (action != 'microphone' && action != 'deafen') return 'blocked';
    final ticket = scope.capture();
    final revision = operationRevision;
    final target = room;
    if (!active(ticket, revision) || _running[this] != null) return 'blocked';
    if (target == null ||
        deafenChanging ||
        ![VoicePhase.connected, VoicePhase.listener].contains(voicePhase)) {
      voiceShortcutStatus =
          'Действие недоступно: голосовое подключение не готово.';
      notifyListeners();
      return 'blocked';
    }
    if (action == 'microphone' &&
        (deafened ||
            listenerOnly ||
            microphoneUnavailable ||
            audioActivationMode == AudioActivationMode.ptt ||
            voicePhase == VoicePhase.listener)) {
      voiceShortcutStatus = 'Микрофон остаётся выключенным.';
      notifyListeners();
      return 'blocked';
    }
    final token = Object();
    _running[this] = token;
    _cancelled[this] = null;
    final previous = action == 'microphone' ? microphoneMuted : deafened;
    try {
      if (action == 'microphone') {
        await toggleMicrophone();
      } else {
        await toggleDeafen();
      }
      if (!active(ticket, revision) ||
          !identical(room, target) ||
          (!identical(_running[this], token) ||
              identical(_cancelled[this], token)))
        return 'blocked';
      final next = action == 'microphone' ? microphoneMuted : deafened;
      voiceShortcutStatus = previous == next
          ? (action == 'microphone'
                ? 'Микрофон не изменён.'
                : 'Звук не изменён.')
          : action == 'microphone'
          ? (next ? 'Микрофон выключен.' : 'Микрофон включён.')
          : (next ? 'Звук выключен.' : 'Звук включён.');
      notifyListeners();
      return previous == next ? 'blocked' : 'applied';
    } catch (_) {
      if (active(ticket, revision) &&
          identical(room, target) &&
          identical(_running[this], token) &&
          !identical(_cancelled[this], token)) {
        voiceShortcutStatus = 'Не удалось изменить состояние аудио.';
        notifyListeners();
      }
      return 'blocked';
    } finally {
      if (identical(_running[this], token)) _running[this] = null;
    }
  }
}
