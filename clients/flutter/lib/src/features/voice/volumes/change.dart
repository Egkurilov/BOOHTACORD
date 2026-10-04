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
      final saving = preferences.setParticipant(accountId, level);
      notifyListeners();
      await Future.wait([
        saving,
        applyParticipantVolume(participant, level),
      ]);
      if (active(ticket, revision)) { volumePreferenceOutcome('success'); notifyListeners(); }
    } catch (_) {
      if (!active(ticket, revision)) return;
      volumePreferenceOutcome(preferences.status == 'fallback' ? 'fallback' : 'error');
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
      final saving = preferences != null && accountId != null
          ? preferences.setScreen(accountId, level) : Future<void>.value();
      notifyListeners();
      await Future.wait([saving, applyParticipantVolume(
        participant,
        screenShareAudioMuted(participant) ? 0 : level,
        TrackSource.screenShareAudio,
      )]);
      if (active(ticket, revision)) { volumePreferenceOutcome(voiceVolumePreferences?.status ?? 'fallback'); notifyListeners(); }
    } catch (_) {
      if (!active(ticket, revision)) return;
      volumePreferenceOutcome(voiceVolumePreferences?.status == 'fallback' ? 'fallback' : 'error');
      if (active(ticket, revision)) notifyListeners();
    }
  }
}
