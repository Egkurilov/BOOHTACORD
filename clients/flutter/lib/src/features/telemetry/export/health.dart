import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import '../action_scope/session.dart';
import 'session_processor.dart';

void recordExportHealth(TelemetrySession? session) {
  final owner = session?.snapshot();
  if (owner?.binding == null) return;
  final status = telemetryExportStatus;
  final age = status.lastAcceptedAt;
  OTel.tracer()
      .startSpan(
        'telemetry.export.health',
        context: Context.root,
        kind: SpanKind.internal,
        attributes: OTel.attributesFromMap({
          'app.schema.version': 1,
          'session.id': owner!.binding!,
          'app.visit.id': owner.visit,
          'app.flow.id': diagnosticId(),
          'app.flow.name': 'telemetry.export',
          'app.flow.attempt': 1,
          'app.flow.stage': 'export',
          'app.flow.record': 'checkpoint',
          'app.flow.outcome': 'unknown',
          'app.provenance': 'client_observed',
          'app.export.queued': status.queued,
          'app.export.accepted': status.accepted,
          'app.export.rejected': status.rejected,
          'app.export.dropped': status.dropped,
          'app.export.retried': status.retried,
          if (age != null)
            'app.export.age_ms': DateTime.now()
                .difference(age)
                .inMilliseconds
                .clamp(0, 86400000),
        }),
      )
      .end();
}
