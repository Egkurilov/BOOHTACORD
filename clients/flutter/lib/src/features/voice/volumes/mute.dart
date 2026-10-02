import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import '../screen_viewer/audio_toggle.dart';

extension VoiceVolumesMute on VoiceController {
  Future<void> toggleScreenShareAudio(RemoteParticipant participant) =>
      toggleScreenAudioWithCallbacks(
        volume: screenShareVolume(participant),
        muted: screenShareAudioMuted(participant),
        setVolume: (percent) => setScreenShareVolume(participant, percent),
        setMuted: (muted) => setScreenShareAudioMuted(participant, muted),
      );

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
    final savedVolume = screenShareVolume(participant) ?? 100;
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
