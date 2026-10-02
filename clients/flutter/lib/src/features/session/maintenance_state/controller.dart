import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';

class MaintenanceController extends ChangeNotifier {
  MaintenanceController(this.api);
  final ApiClient api;
  Timer? timer;
  bool active = false;
  bool disposed = false;
  int revision = 0;
  void start() {
    if (disposed) return;
    unawaited(refresh());
    timer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (disposed) return;
    final expected = ++revision;
    final session = api.transport.session;
    final ticket = session.scope.capture();
    final server = session.serverRevision;
    bool current() =>
        !disposed &&
        expected == revision &&
        ticket.isCurrent &&
        server == session.serverRevision;
    var value = false;
    try {
      value = await api.maintenanceActive();
    } catch (_) {}
    if (!current() || value == active) return;
    active = value;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    revision++;
    timer?.cancel();
    timer = null;
    super.dispose();
  }
}
