import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import 'publication_current.dart';

void retryRemoteScreenViewerSubscription(
  VoiceController voice,
  RemoteTrackPublication publication,
  bool Function() isCurrent, {
  bool manual = false,
}) {
  final generation = voice.selectedRemoteScreenViewerGeneration;
  if (generation == null ||
      !voice.remoteScreenViewerForeground ||
      voice.remoteScreenViewerRecoveryInFlightGeneration == generation ||
      voice.remoteScreenViewerFirstFrameGeneration == generation ||
      (!manual && voice.remoteScreenViewerRecoveryAttempt >= 2) ||
      !isCurrent() ||
      currentRemoteScreenViewerPublication(voice, publication) == null) {
    return;
  }
  voice.remoteScreenViewerRecoveryTimer?.cancel();
  voice.remoteScreenViewerRecoveryTimer = null;
  voice.remoteScreenViewerRecoveryDeadline.reset();
  voice.remoteScreenViewerRecoveryAttempt = 1;
  voice.remoteScreenViewerRecoveryInFlightGeneration = generation;
  voice.notifyListeners();
  var deferredForForeground = false;
  final operation = voice.remoteScreenSubscriptionTail
      .catchError((Object _) {})
      .then((_) async {
        if (!isCurrent() ||
            currentRemoteScreenViewerPublication(voice, publication) == null) {
          return;
        }
        if (!voice.remoteScreenViewerForeground) {
          deferredForForeground = true;
          return;
        }
        final current = currentRemoteScreenViewerPublication(
          voice,
          publication,
        );
        if (current == null) return;
        // One SDK subscription cycle is the bounded fallback. LiveKit then
        // supplies the fresh track through the normal renderer binding path.
        await voice.setRemoteTrackSubscription(current, false);
        if (!isCurrent() ||
            currentRemoteScreenViewerPublication(voice, publication) == null) {
          return;
        }
        if (!voice.remoteScreenViewerForeground) {
          deferredForForeground = true;
          return;
        }
        final replacement = currentRemoteScreenViewerPublication(
          voice,
          publication,
        );
        if (replacement != null) {
          await voice.setRemoteTrackSubscription(replacement, true);
        }
      });
  voice.remoteScreenSubscriptionTail = operation;
  unawaited(
    operation.then<void>(
      (_) => _finishRemoteScreenViewerRecovery(
        voice,
        generation,
        publication,
        isCurrent,
        deferredForForeground: deferredForForeground,
      ),
      onError: (Object error, StackTrace stackTrace) =>
          _finishRemoteScreenViewerRecovery(
            voice,
            generation,
            publication,
            isCurrent,
            deferredForForeground: deferredForForeground,
          ),
    ),
  );
}

void _finishRemoteScreenViewerRecovery(
  VoiceController voice,
  Object generation,
  RemoteTrackPublication publication,
  bool Function() isCurrent, {
  required bool deferredForForeground,
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
    scheduleRemoteScreenViewerRecovery(voice, publication, isCurrent);
  }
}
