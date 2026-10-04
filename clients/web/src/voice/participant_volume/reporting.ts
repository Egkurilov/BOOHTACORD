import { trace, SpanKind } from '@opentelemetry/api'
export function createVolumeReporter() {
  const last = new Map<string, number>()
  return (outcome: 'success' | 'fallback' | 'error'): void => {
    const now = Date.now()
    if (now - (last.get(outcome) ?? -Infinity) < 5000) return
    last.set(outcome, now)
    const span = trace.getTracer('boohtacord/web').startSpan('voice.volume.preference', { kind: SpanKind.CLIENT })
    span.setAttributes({ 'client.platform': 'web', volume_preference_apply: outcome })
    span.end()
  }
}
