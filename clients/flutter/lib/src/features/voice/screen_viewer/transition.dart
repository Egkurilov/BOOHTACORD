import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import 'recovery.dart';

bool _samePublication(
  RemoteTrackPublication? first,
  RemoteTrackPublication? second,
) =>
    first?.sid == second?.sid &&
    first?.participant.identity == second?.participant.identity;

void queueRemoteScreenSubscriptionTransition(
  VoiceController voice, {
  required RemoteTrackPublication? previousPublication,
  required RemoteTrackPublication? previousAudioPublication,
  required RemoteTrackPublication? nextPublication,
  required RemoteTrackPublication? nextAudioPublication,
  required bool Function() isCurrent,
}) {
  final videoChanged = !_samePublication(previousPublication, nextPublication);
  final audioChanged =
      !_samePublication(previousAudioPublication, nextAudioPublication);
  final transition = voice.remoteScreenSubscriptionTail
      .catchError((Object _) {})
      .then((_) async {
        if (videoChanged && previousPublication != null) {
          await voice.setRemoteTrackSubscription(previousPublication, false);
        }
        if (audioChanged && previousAudioPublication != null) {
          await voice.setRemoteTrackSubscription(
            previousAudioPublication,
            false,
          );
        }
        if (!isCurrent()) return;
        if (videoChanged && nextPublication != null) {
          armRemoteScreenViewerRecovery(voice, nextPublication, isCurrent);
          await voice.setRemoteTrackSubscription(
            nextPublication,
            true,
          );
        }
        if (audioChanged && nextAudioPublication != null) {
          await voice.setRemoteTrackSubscription(nextAudioPublication, true);
        }
      });
  voice.remoteScreenSubscriptionTail = transition;
  unawaited(transition);
}
