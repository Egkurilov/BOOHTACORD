import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';
import '../screen_preview/capture_policy.dart';
import 'audio_publication.dart';
import 'discovery.dart';
import 'publication_generation.dart';
import 'recovery.dart';
import 'transition.dart';

extension VoiceScreenViewerPublicationSubscription on VoiceController {
  void subscribeRemoteScreenForViewing(Room room, String identity) {
    if (!identical(this.room, room) ||
        selectedRemoteScreenViewerIdentity != identity) {
      return;
    }
    final participant = room.remoteParticipants[identity];
    if (participant == null) return;
    final publication = firstDiscoverableRemoteScreenPublication(participant);
    if (publication == null) return;
    final audioPublication = screenShareAudioPublication(participant);
    final generation = ScreenViewerPublicationGeneration(
      participantIdentity: identity,
      publicationSid: publication.sid,
    );
    final previousPublication = selectedRemoteScreenViewerPublication;
    final previousAudioPublication =
        selectedRemoteScreenViewerAudioPublication;
    if (generation != selectedRemoteScreenViewerGeneration ||
        audioPublication?.sid != previousAudioPublication?.sid) {
      if (generation != selectedRemoteScreenViewerGeneration) {
        remoteScreenViewerRecoveryTimer?.cancel();
        remoteScreenViewerRecoveryTimer = null;
        remoteScreenViewerRecoveryAttempt = 0;
        remoteScreenViewerRecoveryDeadline.reset();
        remoteScreenViewerRecoveryInFlightGeneration = null;
        remoteScreenViewerRecoveryPublication = null;
        remoteScreenViewerRecoveryIsCurrent = null;
        remoteScreenViewerFirstFrameGeneration = null;
      }
      screenViewerSelectionRevision++;
      final selectionRevision = screenViewerSelectionRevision;
      selectedRemoteScreenViewerGeneration = generation;
      selectedRemoteScreenViewerPublication = publication;
      selectedRemoteScreenViewerAudioPublication = audioPublication;
      final ticket = scope.capture();
      final operationRevision = this.operationRevision;
      queueRemoteScreenSubscriptionTransition(
        this,
        previousPublication: previousPublication,
        previousAudioPublication: previousAudioPublication,
        nextPublication: publication,
        nextAudioPublication: audioPublication,
        isCurrent: () =>
            active(ticket, operationRevision) &&
            selectedRemoteScreenViewerIdentity == identity &&
            selectionRevision == screenViewerSelectionRevision,
      );
    } else {
      selectedRemoteScreenViewerPublication = publication;
      selectedRemoteScreenViewerAudioPublication = audioPublication;
    }
    final track = publication.track;
    if (track is RemoteVideoTrack) {
      unawaited(
        captureSelectedRemoteScreenThumbnail(
          capture: () => captureRemoteThumbnail(
            room,
            participant,
            publication,
            track,
          ),
          source: publication.source,
          isRemoteVideoTrack: true,
          participantIdentity: participant.identity,
          selectedIdentity: selectedRemoteScreenViewerIdentity,
        ),
      );
    }
  }

  void subscribeRemoteScreenAudioForViewing(
    RemoteTrackPublication publication,
  ) {
    if (selectedRemoteScreenViewerIdentity !=
        publication.participant.identity) {
      return;
    }
    final previous = selectedRemoteScreenViewerAudioPublication;
    if (previous?.sid == publication.sid) return;
    selectedRemoteScreenViewerAudioPublication = publication;
    final ticket = scope.capture();
    final operationRevision = this.operationRevision;
    final selectionRevision = screenViewerSelectionRevision;
    queueRemoteScreenSubscriptionTransition(
      this,
      previousPublication: selectedRemoteScreenViewerPublication,
      previousAudioPublication: previous,
      nextPublication: selectedRemoteScreenViewerPublication,
      nextAudioPublication: publication,
      isCurrent: () =>
          active(ticket, operationRevision) &&
          selectionRevision == screenViewerSelectionRevision,
    );
  }
}
