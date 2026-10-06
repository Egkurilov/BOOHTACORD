import { expect,it } from 'vitest'
import { eventLinks,processRealtime,trackRealtimeMessages } from './process'
import { observeMessageRender } from '../observe_render/messages'
import { trace } from '@opentelemetry/api'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { telemetrySession } from '../action_scope/session'
import type { RealtimeTelemetryEvent } from './process'
it('retains bounded multi-cause links without exporting message content',()=>{
 const events=Array.from({length:50},(_,i)=>({eventId:String(i),kind:'message.created',occurredAt:new Date().toISOString(),
 payload:{body:'private'},telemetry:{traceId:'1'.repeat(32),spanId:i.toString(16).padStart(16,'0'),reference:'proof'+i}})) as RealtimeTelemetryEvent[]
 const links=eventLinks(events)
 expect(links).toHaveLength(8);expect(JSON.stringify(links)).not.toContain('private')
})
it('finishes both coalesced causes only after the actual shared message render',async()=>{
 const exporter=new InMemorySpanExporter(),provider=new BasicTracerProvider({spanProcessors:[new SimpleSpanProcessor(exporter)]})
 trace.setGlobalTracerProvider(provider);telemetrySession.bind('1'.repeat(32),'1')
 const event:RealtimeTelemetryEvent={kind:'message.created',payload:{message_id:'target'}}
 const message={id:'target'},refresh=Promise.resolve()
 await Promise.all([processRealtime([event],()=>refresh),processRealtime([event],()=>refresh)])
 trackRealtimeMessages([message])
 expect(exporter.getFinishedSpans().filter(s=>s.attributes['app.flow.outcome']==='success')).toHaveLength(0)
 observeMessageRender(message)
 const completed=exporter.getFinishedSpans().filter(s=>s.attributes['app.flow.outcome']==='success')
 expect(completed).toHaveLength(2);expect(new Set(completed.map(s=>s.attributes['app.flow.id'])).size).toBe(2)
 telemetrySession.reset();await provider.shutdown();trace.disable()
})

