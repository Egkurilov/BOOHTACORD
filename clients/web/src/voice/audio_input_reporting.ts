import { SpanKind, SpanStatusCode, trace, type Tracer } from '@opentelemetry/api'
import type { AudioInputPhase, AudioInputSelection } from './audio_input_selection'

export function reportAudioInputSwitch(phase: AudioInputPhase, result: AudioInputSelection['outcome'], tracer: Tracer = trace.getTracer('boohtacord/web')): void {
  const span = tracer.startSpan('audio.input.switch', { kind: SpanKind.CLIENT })
  span.setAttributes({ platform: 'web', phase, result })
  if (result === 'error') span.setStatus({ code: SpanStatusCode.ERROR })
  span.end()
}
