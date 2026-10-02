import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../lifecycle/controller.dart';
import '../screen_viewer/audio_publication.dart';

extension VoiceVolumesApply on VoiceController {
  Future<void> applySavedVoiceVolumes(Room room) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    for (final participant in room.remoteParticipants.values) {
      await applySavedParticipantVolume(participant);
      if (!active(ticket, revision)) return;
      await applySavedAudioVolume(participant, TrackSource.screenShareAudio);
      if (!active(ticket, revision)) return;
    }
  }

  Future<void> applySavedParticipantVolume(RemoteParticipant participant) =>
      applySavedAudioVolume(participant, TrackSource.microphone);

  Future<void> applySavedAudioVolume(
    RemoteParticipant participant,
    TrackSource source,
  ) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    try {
      if (source == TrackSource.screenShareAudio &&
          screenShareAudioMuted(participant)) {
        await applyParticipantVolume(participant, 0, source);
        if (!active(ticket, revision)) return;
        return;
      }
      if (source == TrackSource.screenShareAudio) {
        await applyParticipantVolume(
          participant,
          screenShareVolume(participant) ?? 100,
          source,
        );
        if (!active(ticket, revision)) return;
        return;
      }
      final accountId = voiceAccountId(participant);
      final preferences = voiceVolumePreferences;
      if (accountId == null || preferences == null) {
        return;
      }
      await applyParticipantVolume(
        participant,
        preferences.participant(accountId),
        source,
      );
      if (!active(ticket, revision)) return;
    } catch (_) {
      if (!active(ticket, revision)) return;
      error = 'Не удалось применить сохранённую громкость участника.';
      if (active(ticket, revision)) notifyListeners();
    }
  }

  Future<void> applyParticipantVolume(
    RemoteParticipant participant,
    int level, [
    TrackSource source = TrackSource.microphone,
  ]) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    if (source == TrackSource.screenShareAudio) {
      final publication = screenShareAudioPublication(participant);
      final track = publication?.track;
      if (track != null) {
        await rtc.Helper.setVolume(level / 100, track.mediaStreamTrack);
      }
      if (!active(ticket, revision)) return;
      return;
    }
    for (final publication in participant.audioTrackPublications) {
      if (publication.source == source && publication.track != null) {
        await rtc.Helper.setVolume(
          level / 100,
          publication.track!.mediaStreamTrack,
        );
        if (!active(ticket, revision)) return;
      }
    }
  }
}
