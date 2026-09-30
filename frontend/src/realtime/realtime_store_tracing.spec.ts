import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { trace } from '@opentelemetry/api'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'

import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

afterEach(() => trace.disable())

it('finishes a cancelled connection with one failed event', async () => {
  setActivePinia(createPinia())
  const exporter = new InMemorySpanExporter()
  const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
  trace.setGlobalTracerProvider(provider)
  const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
  const store = useRealtimeStore()
  let target = ''
  store.connect(vi.fn(), (url) => { target = url; return socket }, 'ws://example.test/api/v1/realtime')
  store.disconnect()
  expect(exporter.getFinishedSpans()).toHaveLength(1)
  const span = exporter.getFinishedSpans()[0]
  expect(new URL(target).searchParams.get('traceparent')).toBe(`00-${span.spanContext().traceId}-${span.spanContext().spanId}-01`)
  expect(exporter.getFinishedSpans()[0].events.map((event) => event.name)).toEqual([
    'app.client.realtime.connect.started', 'app.client.realtime.connect.failed',
  ])
  await provider.shutdown()
})
