import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { trace } from '@opentelemetry/api'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'

import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

afterEach(() => trace.disable())

it('finishes a cancelled connection once without claiming success or network failure', async () => {
  setActivePinia(createPinia())
  const exporter = new InMemorySpanExporter()
  const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
  trace.setGlobalTracerProvider(provider)
  const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
  const store = useRealtimeStore()
  let target = ''
  store.connect(vi.fn(), (url) => { target = url; return socket }, 'ws://example.test/api/v1/realtime')
  store.disconnect()
  const terminals=exporter.getFinishedSpans().filter(span=>span.attributes['app.flow.record']==='terminal')
  expect(terminals).toHaveLength(1)
  const span = terminals[0]
  expect(new URL(target).searchParams.get('traceparent')).toBe(`00-${span.spanContext().traceId}-${span.spanContext().spanId}-01`)
  expect(span.attributes['app.flow.outcome']).toBe('cancelled')
  expect(span.events.map((event)=>event.name)).not.toContain('app.client.realtime.connect.failed')
  await provider.shutdown()
})

it('keeps connect incomplete until connection.ready even after socket open',async()=>{
 setActivePinia(createPinia())
 const exporter=new InMemorySpanExporter(),provider=new BasicTracerProvider({spanProcessors:[new SimpleSpanProcessor(exporter)]})
 trace.setGlobalTracerProvider(provider)
 const socket:RealtimeSocket={close:vi.fn(),onclose:null,onerror:null,onmessage:null,onopen:null}
 const store=useRealtimeStore();store.connect(vi.fn(),()=>socket,'ws://example.test/api/v1/realtime')
 socket.onopen?.({} as Event)
 expect(exporter.getFinishedSpans().some(span=>span.attributes['app.flow.outcome']==='success')).toBe(false)
 socket.onmessage?.({data:JSON.stringify({event_id:'ready',kind:'connection.ready',occurred_at:new Date().toISOString(),payload:{}})} as MessageEvent)
 expect(exporter.getFinishedSpans().filter(span=>span.attributes['app.flow.outcome']==='success')).toHaveLength(1)
 store.disconnect();await provider.shutdown()
})
