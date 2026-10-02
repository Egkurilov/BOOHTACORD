import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import 'event.dart';
import 'close.dart';
export 'connect.dart';
export 'close.dart';
export 'events.dart';
export 'recovery.dart';
export 'event.dart';

class RealtimeController extends ChangeNotifier {
  RealtimeController(
    this.api,
    this.scope, {
    required this.isReady,
    required this.expire,
    required this.invalidatePresence,
    required this.dispatch,
  });
  final ApiClient api;
  final SessionScope scope;
  final bool Function() isReady;
  final Future<void> Function() expire;
  final void Function() invalidatePresence;
  final void Function(RealtimeEvent) dispatch;
  WebSocket? socket;
  StreamSubscription<dynamic>? subscription;
  Timer? retry;
  int attempt = 0;
  int generation = 0;
  bool connecting = false;
  bool connected = false;
  bool checkingSession = false;
  bool disposed = false;
  final Set<String> eventIds = {};

  bool Function() admission() {
    final ticket = scope.capture();
    final current = generation;
    return () =>
        !disposed && ticket.isActive && current == generation && isReady();
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
