import { SpanKind, trace } from '@opentelemetry/api'
import type { VoiceDisconnectNotice } from './model'
export function reportVoiceDisconnect(notice: VoiceDisconnectNotice): void {
  const span = trace.getTracer('boohtacord/web').startSpan('voice.disconnect', { kind: SpanKind.CLIENT })
  span.setAttributes({ 'client.platform': 'web', 'voice.disconnect.reason': notice.reason.toLowerCase(), 'voice.disconnect.source': notice.source, 'voice.reconnect_allowed': notice.reconnectAllowed })
  span.end()
}
