part of 'action.dart';

extension ActionFields on ActionScope {
  void onFinish(void Function() callback) {
    if (_ended) {
      try {
        callback();
      } catch (_) {}
    } else {
      _completion.add(callback);
    }
  }

  void emit(String record, String outcome) {
    observe?.call(fields(record, outcome));
    if (enabled) {
      final checkpoint = OTel.tracer().startSpan(
        name,
        parentSpan: span,
        kind: SpanKind.internal,
        links: links,
      );
      decorate(checkpoint, record, outcome);
      checkpoint.end();
    }
  }

  Map<String, Object> fields(String record, String outcome) => {
    'app.schema.version': 1,
    'app.visit.id': snapshot.visit,
    'app.flow.id': id,
    'app.flow.name': name,
    'app.flow.attempt': attempt,
    'app.flow.stage': stage,
    'app.flow.record': record,
    'app.flow.outcome': outcome,
    'app.provenance': 'client_observed',
    if (snapshot.binding != null) 'session.id': snapshot.binding!,
    'app.client.version': appVersionName,
    if (snapshot.media != null) 'app.media.session.id': snapshot.media!,
  };
  void decorate(Span target, String record, String outcome) {
    for (final entry in fields(record, outcome).entries) {
      if (entry.value is int) {
        target.setIntAttribute(entry.key, entry.value as int);
      } else {
        target.setStringAttribute(entry.key, entry.value as String);
      }
    }
  }

  Map<String, String> headers() =>
      !session.current(snapshot) || snapshot.binding == null
      ? {}
      : {
          'X-Telemetry-Session': snapshot.binding!,
          'X-App-Visit': snapshot.visit,
          'X-App-Flow': id,
          'X-App-Flow-Name': name,
          'X-App-Attempt': '$attempt',
          if (snapshot.media != null) 'X-App-Media-Session': snapshot.media!,
        };
}
