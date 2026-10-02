import 'dart:async';

import 'controller.dart';

extension VoiceRosterStale on VoiceRosterController {
  void markLost(int expected) {
    if (!watching || expected != revision) return;
    if (voiceRosters == null && voiceRosterError == null) {
      voiceRosterError = 'Нет связи со списком голосовых каналов.';
      changed();
    }
    staleTimer ??= Timer(staleTimeout, () {
      staleTimer = null;
      if (!watching || expected != revision) return;
      voiceRosters = null;
      voiceRosterError = 'Нет связи со списком голосовых каналов.';
      changed();
    });
  }
}
