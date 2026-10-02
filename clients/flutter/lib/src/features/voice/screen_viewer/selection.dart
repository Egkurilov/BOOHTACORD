import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';
import 'audio_publication.dart';

extension VoiceScreenViewerSelection on VoiceController {
  Future<void> selectRemoteScreenForViewing(String? participantIdentity) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final nextIdentity = participantIdentity?.trim();
    final next = nextIdentity == null || nextIdentity.isEmpty
        ? null
        : nextIdentity;
    final previous = selectedRemoteScreenViewerIdentity;
    if (previous == next) return;
    selectedRemoteScreenViewerIdentity = next;
    final room = this.room;
    if (room == null) return;

    if (previous != null) {
      final participant = room.remoteParticipants[previous];
      if (participant != null) {
        for (final publication in participant.videoTrackPublications.where(
          (item) => item.source == TrackSource.screenShareVideo,
        )) {
          if (!screenThumbnailRemoteTrackIds.containsKey(publication.sid)) {
            await setRemoteTrackSubscription(publication, false);
            if (!active(ticket, revision)) return;
          }
        }
        final audioPublication = screenShareAudioPublication(participant);
        if (audioPublication != null) {
          await setRemoteTrackSubscription(audioPublication, false);
          if (!active(ticket, revision)) return;
        }
      }
    }

    if (next == null ||
        !isCurrentScreenViewerSelection(
          next,
          selectedRemoteScreenViewerIdentity,
        )) {
      return;
    }
    subscribeRemoteScreenForViewing(room, next);
  }

  void subscribeRemoteScreenForViewing(Room room, String identity) {
    final participant = room.remoteParticipants[identity];
    if (participant == null) return;
    for (final publication in participant.videoTrackPublications.where(
      (item) => item.source == TrackSource.screenShareVideo,
    )) {
      unawaited(setRemoteTrackSubscription(publication, true));
    }
    final audioPublication = screenShareAudioPublication(participant);
    if (audioPublication != null) {
      unawaited(setRemoteTrackSubscription(audioPublication, true));
    }
  }
}
