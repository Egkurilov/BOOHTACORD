part of 'session_processor.dart';

class RelayFailure extends StateError {
  RelayFailure(this.status, this.retryAfter)
    : super('Telemetry export failed: HTTP $status');
  final int status;
  final Duration retryAfter;
}

class ExportStatus {
  int queued = 0, accepted = 0, rejected = 0, dropped = 0, retried = 0;
  DateTime? lastAcceptedAt;
}

final telemetryExportStatus = ExportStatus();

class _Owner {
  _Owner(this.session, this.snapshot);
  final TelemetrySession session;
  final TelemetrySnapshot snapshot;
  bool get current => session.current(snapshot);
}
