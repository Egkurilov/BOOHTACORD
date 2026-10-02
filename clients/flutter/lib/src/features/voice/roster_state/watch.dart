import 'dart:async';
import 'dart:convert';

import '../../../services/voice_roster_events.dart';
import 'controller.dart';

extension VoiceRosterWatch on VoiceRosterController {
  void start() {
    if (disposed || !scope.capture().isActive || !hasUser() || watching) return;
    watching = true;
    unawaited(watch(++revision));
  }

  Future<void> watch(int expected) async {
    final ticket = scope.capture();
    while (ticket.isActive && watching && expected == revision && isReady()) {
      try {
        final response = await api.voiceRosterEvents();
        if (!ticket.isActive || !watching || expected != revision) {
          await response.stream.listen(null).cancel();
          return;
        }
        final done = Completer<void>();
        streamDone = done;
        subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!ticket.isActive || expected != revision) return;
                if (line == 'event: session-expired') {
                  voiceRosters = null;
                  voiceRosterError = null;
                  changed();
                  api.onUnauthorized?.call();
                  stop();
                  return;
                }
                try {
                  final rooms = parseVoiceRosterEvent(line);
                  if (rooms == null) return;
                  staleTimer?.cancel();
                  staleTimer = null;
                  voiceRosters = rooms;
                  voiceRosterError = null;
                  changed();
                } catch (cause) {
                  voiceRosters = null;
                  voiceRosterError = message(cause);
                  changed();
                }
              },
              onError: (Object _) {
                markLost(expected);
                if (!done.isCompleted) done.complete();
              },
              onDone: () {
                markLost(expected);
                if (!done.isCompleted) done.complete();
              },
            );
        await done.future;
        if (!ticket.isActive || expected != revision) return;
        subscription = null;
        streamDone = null;
      } catch (cause) {
        if (ticket.isActive && expected == revision) {
          if (cause is ApiFailure &&
              (cause.status == 401 || cause.status == 403)) {
            voiceRosters = null;
          }
          if (voiceRosters == null) {
            voiceRosterError = message(cause);
          } else {
            markLost(expected);
          }
          changed();
        }
      }
      if (!ticket.isActive || !watching || expected != revision) return;
      final retry = Completer<void>();
      retryDone = retry;
      retryTimer = Timer(retryDelay, () {
        if (!retry.isCompleted) retry.complete();
      });
      await retry.future;
      if (!ticket.isActive || expected != revision) return;
      retryTimer = null;
      retryDone = null;
    }
  }
}
