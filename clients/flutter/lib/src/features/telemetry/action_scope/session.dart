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
    this.mediaFlow,
  );
  final int generation;
  final String visit, origin;
  final String? binding, media, mediaFlow;
  final SessionTicket ticket;
}

class TelemetrySession {
  TelemetrySession(this.capture, this.readOrigin);
  final SessionTicket Function() capture;
  final String Function() readOrigin;
  int generation = 0;
  String visit = diagnosticId();
  String? binding, media, mediaFlow;
  final Set<void Function()> _listeners = {};
  TelemetrySnapshot snapshot() => TelemetrySnapshot(
    generation,
    visit,
    binding,
    readOrigin(),
    capture(),
    media,
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

  void endMedia() {
    media = null;
    mediaFlow = null;
  }

  void Function() onReset(void Function() f) {
    _listeners.add(f);
    return () => _listeners.remove(f);
  }
}
