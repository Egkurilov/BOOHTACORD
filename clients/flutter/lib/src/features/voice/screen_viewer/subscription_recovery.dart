import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import 'publication_current.dart';

const _screenViewerRecoveryDelay = Duration(seconds: 5);

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
        // One bounded SDK cycle rebinds through the normal renderer path.
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
      (_) => finishRemoteScreenViewerRecovery(
        voice,
        generation,
        publication,
        isCurrent,
        deferredForForeground: deferredForForeground,
        scheduleDeferred: () =>
            scheduleRemoteScreenViewerRecovery(voice, publication, isCurrent),
      ),
      onError: (Object error, StackTrace stackTrace) =>
          finishRemoteScreenViewerRecovery(
            voice,
            generation,
            publication,
            isCurrent,
            deferredForForeground: deferredForForeground,
            scheduleDeferred: () => scheduleRemoteScreenViewerRecovery(
              voice,
              publication,
              isCurrent,
            ),
          ),
    ),
  );
}
