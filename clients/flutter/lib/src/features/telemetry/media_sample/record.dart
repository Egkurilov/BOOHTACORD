import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import '../action_scope/session.dart';
import '../../../services/client_telemetry.dart';

export 'fields.dart';
import 'fields.dart';

void recordMediaSample(
  Map<String, Object> report,
  TelemetrySession session,
  TelemetrySnapshot owner,
) {
  if (!ClientTelemetry.enabled ||
      owner.binding == null ||
      owner.media == null ||
      owner.mediaFlow == null ||
      !session.current(owner) ||
      owner.media != session.media) {
    return;
  }
  final core = <String, Object>{
    'app.schema.version': 1,
    'session.id': owner.binding!,
    'app.visit.id': owner.visit,
    'app.flow.id': owner.mediaFlow!,
    'app.flow.name': 'voice.join',
    'app.flow.attempt': 1,
    'app.flow.stage': 'track',
    'app.flow.record': 'checkpoint',
    'app.flow.outcome': 'unknown',
    'app.provenance': 'client_observed',
    'app.media.session.id': owner.media!,
  };
  final sampled = mediaSampleFields(report),
      presented = sampled.remove('app.media.presented_fps');
  final metadata = <String, Object>{};
  for (final key in ['app.media.direction', 'app.media.sample_state', 'app.media.source', 'app.sample.age_ms', 'app.media.stats_window_ms', 'app.media.stats_source', 'app.media.presentation_source', 'app.media.collection_state']) {
    final value = sampled.remove(key);
    if (value != null) metadata[key] = value;
  }

  void emit(Map<String, Object> attrs) {
    OTel.tracer()
        .startSpan(
          'media.sample',
          kind: SpanKind.internal,
          attributes: OTel.attributesFromMap(attrs),
        )
        .end();
  }

  final entries = sampled.entries.toList(), limit = 31 - core.length - metadata.length;
  if (entries.isEmpty) emit({...core, ...metadata});
  for (var offset = 0; offset < entries.length; offset += limit) {
    emit({...core, ...metadata, ...Map.fromEntries(entries.skip(offset).take(limit))});
  }
  if (presented != null) {
    emit({
      ...core,
      'app.media.direction': metadata['app.media.direction']!,
      'app.media.sample_state': metadata['app.media.sample_state']!,
      if (metadata.containsKey('app.sample.age_ms'))
        'app.sample.age_ms': metadata['app.sample.age_ms']!,
      'app.media.source': 'presentation',
      'app.media.presented_fps': presented,
    });
  }
}
