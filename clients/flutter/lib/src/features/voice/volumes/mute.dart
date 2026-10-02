import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceVolumesMute on VoiceController {
  Future<void> setScreenShareAudioMuted(
    RemoteParticipant participant,
    bool muted,
  ) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final room = this.room;
    if (room == null || !room.remoteParticipants.values.contains(participant)) {
      return;
    }
    final identity = participant.identity;
    if (muted) {
      mutedScreenShareAudioIdentities.add(identity);
    } else {
      mutedScreenShareAudioIdentities.remove(identity);
    }
    final accountId = voiceAccountId(participant);
    final savedVolume = accountId == null
        ? 100
        : voiceVolumePreferences?.screen(accountId) ?? 100;
    try {
      await applyParticipantVolume(
        participant,
        muted ? 0 : savedVolume,
        TrackSource.screenShareAudio,
      );
    } catch (_) {
      if (!active(ticket, revision)) return;
      if (muted) {
        mutedScreenShareAudioIdentities.remove(identity);
      } else {
        mutedScreenShareAudioIdentities.add(identity);
      }
      error = 'Не удалось изменить звук демонстрации.';
    }
    if (active(ticket, revision)) notifyListeners();
  }
}
