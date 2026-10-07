import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import 'subscription_recovery.dart';

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
