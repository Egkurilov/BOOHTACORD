import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import '../action_scope/session.dart';
import '../flow_contract/validate.dart';
import '../../../services/client_telemetry.dart';

Map<String, Object> mediaSampleFields(Map<String, Object> report) {
  final age = report['sample_age_ms'];
  final state = !validFlowField('app.sample.age_ms', age)
      ? 'unknown'
      : (age as num) > 15000
      ? 'stale'
      : 'fresh';
  final fields = <String, Object>{
    'app.media.sample_state': state,
    'app.media.direction': report['direction'] == 'receiver'
        ? 'receiver'
        : 'sender',
    'app.media.source': 'webrtc',
  };
  if (validFlowField('app.sample.age_ms', age)) {
    fields['app.sample.age_ms'] = age!;
  }
  if (state != 'fresh') return fields;
  const metrics = {
    'encoded_fps': 'encoded_fps',
    'decoded_fps': 'decoded_fps',
    'presented_fps': 'presented_fps',
    'rtt_ms': 'rtt_ms',
    'jitter_ms': 'jitter_ms',
    'packet_loss_percent': 'loss_percent',
    'target_fps': 'target_fps',
  };
  for (final entry in metrics.entries) {
    final value = report[entry.key], key = 'app.media.${entry.value}';
    if (validFlowField(key, value)) fields[key] = value!;
  }
  final bitrate = report['bitrate_kbps'];
  if (bitrate is num &&
      validFlowField('app.media.bitrate_bps', bitrate * 1000)) {
    fields['app.media.bitrate_bps'] = bitrate * 1000;
  }
  final window = report['packet_loss_window_ms'];
  if (validFlowField('app.sample.window_ms', window)) {
    fields['app.sample.window_ms'] = window!;
  }
  final adaptation = report['adaptation_reason'];
  if (validFlowField('app.media.adaptation_reason', adaptation)) {
    fields['app.media.adaptation_reason'] = adaptation!;
  }
  return fields;
}

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
  final fields = {...core, ...sampled};
  void emit(Map<String, Object> attrs) {
    OTel.tracer()
        .startSpan(
          'media.sample',
          kind: SpanKind.internal,
          attributes: OTel.attributesFromMap(attrs),
        )
        .end();
  }

  emit(fields);
  if (presented != null) {
    emit({
      ...core,
      'app.media.direction': sampled['app.media.direction']!,
      'app.media.sample_state': sampled['app.media.sample_state']!,
      if (sampled.containsKey('app.sample.age_ms'))
        'app.sample.age_ms': sampled['app.sample.age_ms']!,
      'app.media.source': 'presentation',
      'app.media.presented_fps': presented,
    });
  }
}
