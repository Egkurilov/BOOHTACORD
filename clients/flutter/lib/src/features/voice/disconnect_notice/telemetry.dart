import 'package:flutter/foundation.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import '../../../services/client_telemetry.dart';
import 'model.dart';
void reportVoiceDisconnect(VoiceDisconnectNotice notice) {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
  if (!ClientTelemetry.enabled || !{'web', 'android', 'ios', 'windows', 'macos'}.contains(platform)) return;
  final span = OTel.tracer().startSpan('voice.disconnect', kind: SpanKind.client);
  span.setStringAttribute('client.platform', platform);
  span.setStringAttribute('voice.disconnect.reason', notice.reason.toLowerCase());
  span.setStringAttribute('voice.disconnect.source', notice.source);
  span.setBoolAttribute('voice.reconnect_allowed', notice.reconnectAllowed);
  span.end();
}
