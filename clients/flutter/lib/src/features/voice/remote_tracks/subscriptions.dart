import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceRemoteTracksSubscriptions on VoiceController {
  void subscribeCurrentRemoteVoiceTracks(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications.where(
        (item) => item.source == TrackSource.microphone,
      )) {
        unawaited(setRemoteTrackSubscription(publication, true));
      }
      for (final publication in participant.videoTrackPublications.where(
        (item) => item.source == TrackSource.screenShareVideo,
      )) {
        queueRemoteScreenThumbnail(room, participant, publication);
      }
    }
  }

  Future<void> setRemoteTrackSubscription(
    RemoteTrackPublication publication,
    bool subscribed,
  ) async {
    try {
      if (subscribed) {
        await publication.subscribe();
      } else {
        await publication.unsubscribe();
      }
    } catch (_) {
      // Subscription failures leave the screen viewer on its avatar fallback.
    }
  }
}
