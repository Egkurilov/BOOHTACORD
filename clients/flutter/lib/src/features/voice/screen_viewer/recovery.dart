import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import 'subscription_recovery.dart';

const _screenViewerRecoveryDelay = Duration(seconds: 5);

void armRemoteScreenViewerRecovery(
  VoiceController voice,
  RemoteTrackPublication publication,
  bool Function() isCurrent,
) {
  final generation = voice.selectedRemoteScreenViewerGeneration;
  if (generation?.participantIdentity == publication.participant.identity &&
      generation?.publicationSid == publication.sid &&
      voice.remoteScreenViewerFirstFrameGeneration == generation) {
    return;
  }
  voice.remoteScreenViewerRecoveryTimer?.cancel();
  voice.remoteScreenViewerRecoveryDeadline.reset();
  voice.remoteScreenViewerRecoveryAttempt = 0;
  voice.remoteScreenViewerRecoveryInFlightGeneration = null;
  voice.remoteScreenViewerRecoveryPublication = publication;
  voice.remoteScreenViewerRecoveryIsCurrent = isCurrent;
  scheduleRemoteScreenViewerRecovery(voice, publication, isCurrent);
}

void scheduleRemoteScreenViewerRecovery(
  VoiceController voice,
  RemoteTrackPublication publication,
  bool Function() isCurrent,
) {
  final generation = voice.selectedRemoteScreenViewerGeneration;
  if (generation == null ||
      !voice.remoteScreenViewerForeground ||
      voice.remoteScreenViewerRecoveryAttempt >= 2 ||
      voice.remoteScreenViewerRecoveryInFlightGeneration == generation ||
      !isCurrent()) {
    return;
  }
  voice.remoteScreenViewerRecoveryTimer?.cancel();
  voice.remoteScreenViewerRecoveryDeadline.start();
  voice.remoteScreenViewerRecoveryTimer = Timer(
    voice.remoteScreenViewerRecoveryDeadline.remaining,
    () {
      voice.remoteScreenViewerRecoveryDeadline.expire();
      voice.remoteScreenViewerRecoveryTimer = null;
      retryRemoteScreenViewerSubscription(voice, publication, isCurrent);
    },
  );
}
