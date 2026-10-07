import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

RemoteTrackPublication? currentRemoteScreenViewerPublication(
  VoiceController voice,
  RemoteTrackPublication publication,
) {
  final generation = voice.selectedRemoteScreenViewerGeneration;
  final participant = voice.room?.remoteParticipants[
    publication.participant.identity
  ];
  if (generation?.participantIdentity != publication.participant.identity ||
      generation?.publicationSid != publication.sid ||
      voice.selectedRemoteScreenViewerIdentity !=
          publication.participant.identity) {
    return null;
  }
  final current = participant?.videoTrackPublications
      .where((item) => item.sid == publication.sid)
      .firstOrNull;
  if (current == null ||
      current.source != TrackSource.screenShareVideo ||
      current.muted ||
      !current.subscriptionAllowed) {
    return null;
  }
  return current;
}

void finishRemoteScreenViewerRecovery(
  VoiceController voice,
  Object generation,
  RemoteTrackPublication publication,
  bool Function() isCurrent, {
  required bool deferredForForeground,
  required void Function() scheduleDeferred,
}) {
  if (voice.remoteScreenViewerRecoveryInFlightGeneration != generation) return;
  voice.remoteScreenViewerRecoveryInFlightGeneration = null;
  if (voice.selectedRemoteScreenViewerGeneration == generation &&
      voice.remoteScreenViewerFirstFrameGeneration != generation &&
      isCurrent() &&
      currentRemoteScreenViewerPublication(voice, publication) != null) {
    voice.remoteScreenViewerRecoveryAttempt = deferredForForeground ? 0 : 2;
  } else {
    voice.remoteScreenViewerRecoveryAttempt = 0;
  }
  voice.notifyListeners();
  if (deferredForForeground && voice.remoteScreenViewerForeground) {
    scheduleDeferred();
  }
}
