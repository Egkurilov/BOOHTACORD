import { expect,it,vi } from 'vitest'
import { BasicTracerProvider } from '@opentelemetry/sdk-trace-base'
import { SessionProcessor } from './processor'
import { TelemetrySession } from '../action_scope/session'
it('drops after two bounded 429 retries while independent work continues',async()=>{
 vi.useFakeTimers()
 const session=new TelemetrySession();session.bind('1'.repeat(32),'1')
 const send=vi.fn(async()=>new Response(null,{status:429,headers:{'Retry-After':'3600'}}))
 const processor=new SessionProcessor(session,send),provider=new BasicTracerProvider({spanProcessors:[processor]})
 provider.getTracer('test').startSpan('voice.join').end()
 const pending=processor.forceFlush()
 let productReady=false;await Promise.resolve().then(()=>{productReady=true})
 expect(productReady).toBe(true)
 await vi.advanceTimersByTimeAsync(4300);await pending
 expect(send).toHaveBeenCalledTimes(3);expect(processor.status.retried).toBe(2)
 expect(processor.status.dropped).toBe(1);expect(processor.status.queued).toBe(0)
 await provider.shutdown();vi.useRealTimers()
})
it('aborts the old in-flight batch and ignores a late acknowledgement after account change',async()=>{
 const session=new TelemetrySession();session.bind('1'.repeat(32),'1')
 let acknowledge!:(r:Response)=>void,signal:AbortSignal|undefined
 const send=vi.fn((_url:RequestInfo|URL,init?:RequestInit)=>{signal=init?.signal as AbortSignal;return new Promise<Response>(resolve=>{acknowledge=resolve})})
 const processor=new SessionProcessor(session,send),provider=new BasicTracerProvider({spanProcessors:[processor]})
 provider.getTracer('test').startSpan('voice.join').end()
 const pending=processor.forceFlush();session.reset();session.bind('2'.repeat(32),'1')
 expect(signal?.aborted).toBe(true)
 acknowledge(new Response(null,{status:202}));await pending
 expect(processor.status.accepted).toBe(0);expect(processor.status.lastAcceptedAt).toBeNull();expect(processor.status.dropped).toBe(1)
 await provider.shutdown()
})
it('bounds pending records and discards batches across account changes',async()=>{
 vi.useFakeTimers()
 const session=new TelemetrySession();session.bind('11111111111111111111111111111111','1')
 const send=vi.fn(async()=>new Response(null,{status:202}))
 const processor=new SessionProcessor(session,send),provider=new BasicTracerProvider({spanProcessors:[processor]})
 const tracer=provider.getTracer('test')
 const pending=tracer.startSpan('voice.join')
 for(let i=0;i<150;i++)tracer.startSpan('voice.join').end()
 expect(processor.status.queued).toBe(128);expect(processor.status.dropped).toBe(22)
 session.reset();session.bind('22222222222222222222222222222222','1');pending.end()
 await processor.forceFlush()
 expect(send).not.toHaveBeenCalled();expect(processor.status.queued).toBe(0)
 await provider.shutdown();vi.useRealTimers()
})
it('accepts partial batches once and never retries an authentication rejection',async()=>{
 const session=new TelemetrySession();session.bind('11111111111111111111111111111111','1')
 const send=vi.fn(async()=>new Response(null,{status:202,headers:{'X-Telemetry-Accepted':'0','X-Telemetry-Rejected':'1'}}))
 const processor=new SessionProcessor(session,send),provider=new BasicTracerProvider({spanProcessors:[processor]})
 provider.getTracer('test').startSpan('voice.join').end();await processor.forceFlush()
 expect(processor.status.rejected).toBe(1);expect(send).toHaveBeenCalledTimes(1)
 send.mockImplementation(async()=>new Response(null,{status:401}))
 provider.getTracer('test').startSpan('voice.join').end();await processor.forceFlush()
 expect(send).toHaveBeenCalledTimes(2);expect(processor.status.queued).toBe(0)
 await provider.shutdown()
})

