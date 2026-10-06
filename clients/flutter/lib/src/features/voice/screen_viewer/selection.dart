import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';
import '../screen_preview/capture_policy.dart';
import 'audio_publication.dart';
import '../../telemetry/observe_render/view.dart';

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
    if (next == null) {
      stopView(api.transport.session.telemetry);
    } else {
      beginView(api.transport.session.telemetry);
    }
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
      final subscribedTrack = publication.track;
      if (subscribedTrack is RemoteVideoTrack) {
        unawaited(
          captureSelectedRemoteScreenThumbnail(
            temporaryPreview: false,
            capture: () => captureRemoteThumbnail(
              room,
              participant,
              publication,
              subscribedTrack,
            ),
            source: publication.source,
            isRemoteVideoTrack: true,
            participantIdentity: participant.identity,
            selectedIdentity: selectedRemoteScreenViewerIdentity,
          ),
        );
      }
      unawaited(setRemoteTrackSubscription(publication, true));
    }
    final audioPublication = screenShareAudioPublication(participant);
    if (audioPublication != null) {
      unawaited(setRemoteTrackSubscription(audioPublication, true));
    }
  }
}
