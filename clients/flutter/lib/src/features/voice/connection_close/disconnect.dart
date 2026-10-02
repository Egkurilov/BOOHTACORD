import 'package:livekit_client/livekit_client.dart'
    hide voiceReconnectAttemptLimit;

import '../../../services/voice_reconnect_policy.dart';
import '../lifecycle/controller.dart';

extension VoiceConnectionCloseDisconnect on VoiceController {
  Future<void> handleUnexpectedVoiceDisconnect(
    Room room,
    RoomDisconnectedEvent event,
  ) async {
    if (!identical(this.room, room) || voicePhase == VoicePhase.leaving) return;
    final ticket = scope.capture();
    final closing = leaveVoice();
    final revision = operationRevision;
    screenThumbnails.clear();
    await closing;
    if (!active(ticket, revision)) return;
    voicePhase = VoicePhase.error;
    error = switch (event.reason) {
      DisconnectReason.duplicateIdentity =>
        'Голосовое подключение открыто в другом окне. Перенесите его оттуда.',
      DisconnectReason.participantRemoved =>
        'Администратор отключил вас от голосового канала.',
      DisconnectReason.roomDeleted => 'Голосовая комната была закрыта.',
      DisconnectReason.reconnectAttemptsExceeded =>
        'Не удалось восстановить голосовое соединение после $voiceReconnectAttemptLimit попыток. Подключитесь ещё раз.',
      _ => 'Связь с голосовым каналом потеряна. Подключитесь ещё раз.',
    };
    notifyListeners();
  }
}
