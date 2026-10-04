import { expect, it } from 'vitest'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { reportAudioInputSwitch } from './audio_input_reporting'

it('exports only bounded microphone switch outcomes', async () => {
  const exporter = new InMemorySpanExporter()
  const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
  for (const phase of ['prejoin', 'active', 'reconnect'] as const) {
    for (const result of ['success', 'fallback', 'error'] as const) reportAudioInputSwitch(phase, result, provider.getTracer('test'))
  }
  const spans = exporter.getFinishedSpans()
  expect(spans).toHaveLength(9)
  for (const span of spans) {
    expect(span.name).toBe('audio.input.switch')
    expect(Object.keys(span.attributes).sort()).toEqual(['phase', 'platform', 'result'])
    expect(span.attributes.platform).toBe('web')
    expect(span.events).toEqual([])
  }
  await provider.shutdown()
})
