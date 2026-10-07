import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceRemoteTracksSubscriptions on VoiceController {
  void subscribeCurrentRemoteVoiceTracks(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications.where(
        (item) => shouldAutomaticallySubscribeRemoteTrack(item.source),
      )) {
        unawaited(setRemoteTrackSubscription(publication, true));
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

bool shouldAutomaticallySubscribeRemoteTrack(TrackSource source) =>
    source == TrackSource.microphone;
