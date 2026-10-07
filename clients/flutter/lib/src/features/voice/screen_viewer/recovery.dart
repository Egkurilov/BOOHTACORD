import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

const _screenViewerRecoveryDelay = Duration(seconds: 8);

RemoteTrackPublication? _currentScreenPublication(
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
  voice.remoteScreenViewerRecoveryAttempt = 0;
  voice.remoteScreenViewerRecoveryTimer = Timer(
    _screenViewerRecoveryDelay,
    () => _recoverRemoteScreenViewer(voice, publication, isCurrent),
  );
}

void _recoverRemoteScreenViewer(
  VoiceController voice,
  RemoteTrackPublication publication,
  bool Function() isCurrent,
) {
  voice.remoteScreenViewerRecoveryTimer = null;
  if (!isCurrent()) return;
  final current = _currentScreenPublication(voice, publication);
  if (current == null) return;

  if (voice.remoteScreenViewerRecoveryAttempt == 0 && current.track != null) {
    voice.remoteScreenViewerRecoveryAttempt = 1;
    voice.remoteScreenViewerRendererRevision++;
    voice.notifyListeners();
    voice.remoteScreenViewerRecoveryTimer = Timer(
      _screenViewerRecoveryDelay,
      () => _recoverRemoteScreenViewer(voice, publication, isCurrent),
    );
    return;
  }
  if (voice.remoteScreenViewerRecoveryAttempt >= 2) return;

  voice.remoteScreenViewerRecoveryAttempt = 2;
  final operation = voice.remoteScreenSubscriptionTail
      .catchError((Object _) {})
      .then((_) async {
        if (!isCurrent() ||
            _currentScreenPublication(voice, publication) == null) {
          return;
        }
        final current = _currentScreenPublication(voice, publication);
        if (current == null) return;
        await voice.setRemoteTrackSubscription(current, false);
        if (!isCurrent() ||
            _currentScreenPublication(voice, publication) == null) {
          return;
        }
        final currentAfterUnsubscribe = _currentScreenPublication(
          voice,
          publication,
        );
        if (currentAfterUnsubscribe == null) return;
        await voice.setRemoteTrackSubscription(currentAfterUnsubscribe, true);
      });
  voice.remoteScreenSubscriptionTail = operation;
  unawaited(operation);
  voice.remoteScreenViewerRecoveryTimer = Timer(
    _screenViewerRecoveryDelay,
    () => _recoverRemoteScreenViewer(voice, publication, isCurrent),
  );
}
