import 'dart:async';

import '../session/scope.dart';
import 'api_failure.dart';

// A zone follows the complete API operation, including multi-request exchanges.
class RequestScope {
  RequestScope(this.ticket, {this.allowClosed = false, this.sameServer});
  static final Object zoneKey = Object();
  final SessionTicket ticket;
  final bool allowClosed;
  final bool Function()? sameServer;
  static RequestScope? get current => Zone.current[zoneKey] as RequestScope?;
  bool get active =>
      (sameServer?.call() ?? true) &&
      (allowClosed ? ticket.isCurrent : ticket.isActive);
  void ensureCurrent() {
    if (!active) {
      throw const ApiFailure(
        'Сессия изменилась. Повторите действие.',
        code: 'STALE_SESSION',
      );
    }
  }

  Future<T> run<T>(Future<T> Function() operation) => runZoned(() async {
    ensureCurrent();
    final result = await operation();
    ensureCurrent();
    return result;
  }, zoneValues: {zoneKey: this});
}
