import 'package:uuid/uuid.dart';

import '../../../core/session/scope.dart';
import '../flow_contract/validate.dart';

String diagnosticId() => const Uuid().v4().replaceAll('-', '');

class TelemetrySnapshot {
  TelemetrySnapshot(
    this.generation,
    this.visit,
    this.binding,
    this.origin,
    this.ticket,
    this.media,
    this.leaseId,
    this.mediaFlow,
  );
  final int generation;
  final String visit, origin;
  final String? binding, media, leaseId, mediaFlow;
  final SessionTicket ticket;
}

class TelemetrySession {
  TelemetrySession(this.capture, this.readOrigin);
  final SessionTicket Function() capture;
  final String Function() readOrigin;
  int generation = 0;
  String visit = diagnosticId();
  String? binding, media, leaseId, mediaFlow;
  final Set<void Function()> _listeners = {};
  TelemetrySnapshot snapshot() => TelemetrySnapshot(
    generation,
    visit,
    binding,
    readOrigin(),
    capture(),
    media,
    leaseId,
    mediaFlow,
  );
  bool current(TelemetrySnapshot s) =>
      s.generation == generation &&
      s.binding == binding &&
      s.origin == readOrigin() &&
      s.ticket.isCurrent;
  void reset() {
    generation++;
    visit = diagnosticId();
    binding = null;
    media = null;
    leaseId = null;
    mediaFlow = null;
    for (final f in _listeners.toList()) {
      f();
    }
  }

  void bind(String? id, String? schema) {
    if (schema != '1' || !validFlowField('session.id', id)) return;
    if (binding != null && binding != id) reset();
    binding = id;
  }

  String beginMedia() {
    media = diagnosticId();
    mediaFlow = diagnosticId();
    return media!;
  }

  bool bindMediaLease(String id) {
    final compact = id.toLowerCase().replaceAll('-', '');
    if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(id) ||
        !validFlowField('app.media.session.id', compact)) {
      return false;
    }
    leaseId = id.toLowerCase();
    media = compact;
    return true;
  }

  void endMedia() {
    media = null;
    leaseId = null;
    mediaFlow = null;
  }

  void Function() onReset(void Function() f) {
    _listeners.add(f);
    return () => _listeners.remove(f);
  }
}
