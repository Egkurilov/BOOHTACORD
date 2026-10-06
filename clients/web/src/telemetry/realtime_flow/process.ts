import { trace, type Link } from '@opentelemetry/api'
import { nextTick } from 'vue'
import { ActionScope } from '../action_scope/scope'
import { telemetrySession, diagnosticId } from '../action_scope/session'
import type { RealtimeEvent } from '../../realtime/realtime_client'
import { awaitMessageRender } from '../observe_render/messages'
interface Targets {scope:ActionScope;pending:Set<string>}
// A coalesced refresh may run in another cause's context. Preserve every
// waiting observer while keeping independent roots and signed links.
const waiting=new Set<Targets>()
export function trackRealtimeMessages(messages:{id:string}[]):void {
 for(const targets of waiting)for(const message of messages)if(targets.pending.has(message.id))awaitMessageRender(message,targets.scope,()=>{
  targets.pending.delete(message.id)
  if(!targets.pending.size)targets.scope.finish('success')
 })
}
export function eventLinks(events:RealtimeEvent[]):Link[]{
 const seen=new Set<string>(),links:Link[]=[]
 for(const {telemetry} of events){
  if(!telemetry||seen.has(telemetry.reference))continue
  seen.add(telemetry.reference)
  if(links.length<8)links.push({context:{traceId:telemetry.traceId,spanId:telemetry.spanId,traceFlags:1,isRemote:true},
   attributes:{'app.causal.ref':telemetry.reference}})
 }
 return links
}
export async function processRealtime<T>(events:RealtimeEvent[],call:()=>Promise<T>|T):Promise<T>{
 const scope=new ActionScope('realtime.process',trace.getTracer('boohtacord/web'),telemetrySession,1,diagnosticId(),eventLinks(events))
 scope.span.setAttribute('app.cause.truncated',Math.max(0,new Set(events.flatMap(e=>e.telemetry?[e.telemetry.reference]:[])).size-8))
 const targets:Targets={scope,pending:new Set(events.flatMap(event=>event.kind.endsWith('deleted')?[]:typeof event.payload.message_id==='string'?[event.payload.message_id]:[]))}
 waiting.add(targets);scope.onFinish(()=>waiting.delete(targets))
 scope.step('refresh')
 try {
  const value=await scope.within(()=>Promise.resolve(call()))
  // HTTP/model refresh is a checkpoint. A message component closes after render.
  scope.step('render')
  if(!targets.pending.size){await nextTick();scope.finish('success')}
  return value
 } catch(error){scope.finish('failed','dependency');throw error}
}

