import 'dart:async';
import 'package:livekit_client/livekit_client.dart';
import '../lifecycle/controller.dart';

extension VoiceBackgroundMicrophone on VoiceController {
  Future<void> preflightBackgroundMicrophone() async {
    if (!await microphoneForeground.canStart()) {
      preserveBackgroundListener();
      throw StateError('Вернитесь в приложение, чтобы включить микрофон.');
    }
  }
  Future<void> promoteBackgroundMicrophone(LocalParticipant? participant) async {
    if (participant == null || audio.microphoneMutedIntent) {
      await microphoneForeground.stop(); return;
    }
    if (!await microphoneForeground.start()) {
      preserveBackgroundListener();
      await participant.setMicrophoneEnabled(false);
      throw StateError('Не удалось обеспечить работу микрофона в фоне. Подключены как слушатель.');
    }
  }
  void preserveBackgroundListener() {
    audio.microphoneMutedIntent = true; microphoneMuted = true;
    listenerOnly = true;
    if (voicePhase == VoicePhase.connected) voicePhase = VoicePhase.listener;
  }
  void backgroundMicrophoneStopped() {
    if (disposed || room == null) return;
    preserveBackgroundListener(); microphoneUnavailable = true;
    error = 'Android остановил службу микрофона. Включите микрофон из открытого приложения.';
    unawaited(applyMicrophoneMuted(true)); notifyListeners();
  }
}
