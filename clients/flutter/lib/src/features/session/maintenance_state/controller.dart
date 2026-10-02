import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/maintenance_events.dart';

class MaintenanceController extends ChangeNotifier {
  MaintenanceController(
    this.api, {
    this.retryDelay = const Duration(seconds: 2),
  });

  final ApiClient api;
  final Duration retryDelay;
  Timer? retryTimer;
  StreamSubscription<String>? subscription;
  Completer<void>? streamDone;
  Completer<void>? retryDone;
  bool active = false;
  bool watching = false;
  bool disposed = false;
  int revision = 0;

  void start() {
    if (disposed || watching) return;
    watching = true;
    unawaited(watch(++revision));
  }

  void restart() {
    if (disposed) return;
    stop();
    start();
  }

  Future<void> watch(int expected) async {
    final session = api.transport.session;
    bool current() => !disposed && watching && expected == revision;

    while (current()) {
      try {
        final serverRevision = session.serverRevision;
        final response = await api.maintenanceEvents();
        if (!current() || serverRevision != session.serverRevision) {
          await response.stream.listen(null).cancel();
          return;
        }

        final done = Completer<void>();
        streamDone = done;
        final currentSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!current() || serverRevision != session.serverRevision) {
                  return;
                }
                try {
                  final next = parseMaintenanceEvent(line);
                  if (next == null || next == active) return;
                  active = next;
                  notifyListeners();
                } catch (_) {
                  // Ignore malformed frames and keep the last known state.
                }
              },
              onError: (Object _) {
                if (!done.isCompleted) done.complete();
              },
              onDone: () {
                if (!done.isCompleted) done.complete();
              },
            );
        subscription = currentSubscription;
        await done.future;
        if (identical(subscription, currentSubscription)) {
          subscription = null;
        }
        if (identical(streamDone, done)) streamDone = null;
      } catch (_) {}

      if (!current()) return;
      final retry = Completer<void>();
      retryDone = retry;
      retryTimer = Timer(retryDelay, () {
        if (!retry.isCompleted) retry.complete();
      });
      await retry.future;
      if (!current()) return;
      retryTimer = null;
      retryDone = null;
    }
  }

  void stop() {
    watching = false;
    revision++;
    retryTimer?.cancel();
    retryTimer = null;
    final retry = retryDone;
    if (retry != null && !retry.isCompleted) retry.complete();
    retryDone = null;
    final previousSubscription = subscription;
    if (previousSubscription != null) unawaited(previousSubscription.cancel());
    subscription = null;
    final done = streamDone;
    if (done != null && !done.isCompleted) done.complete();
    streamDone = null;
  }

  @override
  void dispose() {
    disposed = true;
    stop();
    super.dispose();
  }
}
