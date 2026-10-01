import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';
import 'effects.dart';
import 'types.dart';

export 'effects.dart';
export 'types.dart';
export 'restore.dart';
export 'authenticate.dart';
export 'close.dart';
export 'server.dart';

class SessionController extends ChangeNotifier {
  SessionController(
    this.api, {
    required this.effects,
    this.startupTimeout = const Duration(seconds: 20),
  });
  final ApiClient api;
  final SessionEffects effects;
  final Duration startupTimeout;
  SessionScope get scope => api.transport.session.scope;
  AppPhase phase = AppPhase.loading;
  SessionUser? user;
  bool logoutBusy = false;
  String? logoutError;
  Future<void>? _closing;
  bool _disposed = false;
  bool get closing => _closing != null;
  Future<void> waitForClose() async {
    while (_closing != null) {
      await _closing;
    }
  }

  Future<void> closeWith(Future<void> Function() operation) async {
    final barrier = Completer<void>();
    _closing = barrier.future;
    try {
      await operation();
    } finally {
      if (identical(_closing, barrier.future)) _closing = null;
      barrier.complete();
    }
  }

  void changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    scope.dispose();
    super.dispose();
  }
}
