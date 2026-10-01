import 'dart:async';

import 'controller.dart';

extension RealtimeRecovery on RealtimeController {
  void handleClosed() {
    final previous = socket;
    generation++;
    socket = null;
    subscription = null;
    connected = false;
    connecting = false;
    if (previous != null) unawaited(previous.close().catchError((Object _) {}));
    invalidatePresence();
    changed();
    unawaited(checkSession());
  }

  Future<void> checkSession() async {
    final active = admission();
    if (!active() || checkingSession) return;
    checkingSession = true;
    try {
      final account = await api.currentSession();
      if (!active()) return;
      if (account == null) {
        await expire();
        return;
      }
    } catch (_) {
      // A transient REST failure does not establish expiration.
    } finally {
      if (active()) checkingSession = false;
    }
    if (active()) scheduleRetry();
  }

  void scheduleRetry() {
    final active = admission();
    if (!active() || retry != null) return;
    invalidatePresence();
    changed();
    final seconds = 1 << attempt.clamp(0, 5);
    attempt++;
    retry = Timer(Duration(seconds: seconds), () {
      retry = null;
      if (active()) unawaited(connect());
    });
  }
}
