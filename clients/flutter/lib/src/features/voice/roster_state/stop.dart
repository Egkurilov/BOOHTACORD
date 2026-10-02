import 'dart:async';

import 'controller.dart';

extension VoiceRosterStop on VoiceRosterController {
  void stop() {
    watching = false;
    retryTimer?.cancel();
    retryTimer = null;
    staleTimer?.cancel();
    staleTimer = null;
    final retry = retryDone;
    if (retry != null && !retry.isCompleted) retry.complete();
    retryDone = null;
    final previousSubscription = subscription;
    if (previousSubscription != null) unawaited(previousSubscription.cancel());
    subscription = null;
    final done = streamDone;
    if (done != null && !done.isCompleted) done.complete();
    streamDone = null;
    revision++;
    loading = false;
  }
}
