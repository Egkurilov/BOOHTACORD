import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/voice_volume_preferences.dart';
import '../lifecycle/controller.dart';

extension VoiceVolumesChange on VoiceController {
  Future<void> setParticipantVolume(
    RemoteParticipant participant,
    num percent,
  ) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final room = this.room;
    final preferences = voiceVolumePreferences;
    final accountId = voiceAccountId(participant);
    if (room == null ||
        preferences == null ||
        accountId == null ||
        !room.remoteParticipants.values.contains(participant)) {
      return;
    }
    final level = VoiceVolumePreferences.normalize(percent);
    try {
      await Future.wait([
        preferences.setParticipant(accountId, level),
        applyParticipantVolume(participant, level),
      ]);
      if (active(ticket, revision)) notifyListeners();
    } catch (_) {
      if (!active(ticket, revision)) return;
      error = 'Не удалось изменить или сохранить громкость участника.';
      if (active(ticket, revision)) notifyListeners();
    }
  }

  Future<void> setScreenShareVolume(
    RemoteParticipant participant,
    num percent,
  ) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final room = this.room;
    final accountId = voiceAccountId(participant);
    if (room == null || !room.remoteParticipants.values.contains(participant)) {
      return;
    }
    final level = VoiceVolumePreferences.normalize(percent);
    try {
      transientScreenShareVolumes[participant.identity] = level;
      final preferences = voiceVolumePreferences;
      if (preferences != null && accountId != null) {
        await preferences.setScreen(accountId, level);
      }
      await applyParticipantVolume(
        participant,
        screenShareAudioMuted(participant) ? 0 : level,
        TrackSource.screenShareAudio,
      );
      if (active(ticket, revision)) notifyListeners();
    } catch (_) {
      if (!active(ticket, revision)) return;
      error = 'Не удалось изменить или сохранить громкость демонстрации.';
      if (active(ticket, revision)) notifyListeners();
    }
  }
}
