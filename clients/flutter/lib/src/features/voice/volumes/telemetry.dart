import 'package:flutter/foundation.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import '../../../services/client_telemetry.dart';
class VolumeTelemetry {
  final _clock = Stopwatch()..start();
  final _last = <String, int>{};
  void submit(String outcome) {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    if (!ClientTelemetry.enabled || !{'success', 'fallback', 'error'}.contains(outcome) ||
        !{'web', 'android', 'ios', 'windows', 'macos'}.contains(platform)) return;
    final now = _clock.elapsedMilliseconds;
    if (now - (_last[outcome] ?? -5000) < 5000) return;
    _last[outcome] = now;
    final span = OTel.tracer().startSpan('voice.volume.preference', kind: SpanKind.client);
    span.setStringAttribute('client.platform', platform);
    span.setStringAttribute('volume_preference_apply', outcome);
    span.end();
  }
}
