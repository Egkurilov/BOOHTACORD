import { createApp,h,ref } from 'vue'
import { createPinia } from 'pinia'
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { InMemorySpanExporter,SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { ZoneContextManager } from '@opentelemetry/context-zone'
import { SessionProcessor } from '../../src/telemetry/export_session/processor'
import { telemetrySession } from '../../src/telemetry/action_scope/session'
import { ActionScope } from '../../src/telemetry/action_scope/scope'
import { createViewObservation } from '../../src/telemetry/observe_render/screen'
import { processRealtime } from '../../src/telemetry/realtime_flow/process'
import { useMessageStore } from '../../src/conversation/message_store'
import MessageItem from '../../src/conversation/MessageItem.vue'
import '../../src/style.css'
const memory=new InMemorySpanExporter(),processor=new SessionProcessor()
const provider=new WebTracerProvider({spanProcessors:[processor,new SimpleSpanProcessor(memory)]})
provider.register({contextManager:new ZoneContextManager()})
const owner='00000000-0000-4000-8000-000000000001',channel='00000000-0000-4000-8000-000000000002'
let store:ReturnType<typeof useMessageStore>
createApp({setup(){
 store=useMessageStore();const draft=ref('private-synthetic-message');store.open(channel)
 return()=>h('main',[h('button',{onClick:()=>store.send(draft.value,undefined,undefined,undefined,[],owner)},'Отправить'),
 ...store.messages.map(message=>h(MessageItem,{key:message.id,message,canEdit:false,canDelete:false}))])
}}).use(createPinia()).mount('#app')
const view=createViewObservation(),video=document.createElement('video')
video.muted=true;video.autoplay=true;document.body.append(video)
let paint:ReturnType<typeof setInterval>|undefined
Object.assign(window,{tracingQA:{
 bind:(binding:string)=>telemetrySession.bind(binding,'1'),
 spans:()=>memory.getFinishedSpans().map(span=>({trace:span.spanContext().traceId,attrs:span.attributes})),
 flush:async()=>{for(let n=0;n<20&&processor.status.queued;n++)await processor.forceFlush();return processor.status},
 receive:()=>processRealtime([{kind:'message.created',payload:{message_id:'00000000-0000-4000-8000-000000000003'}}] as any,()=>store.refresh()),
 select:(present:boolean)=>{
  if(paint)clearInterval(paint);video.srcObject=null
  if(present){const canvas=document.createElement('canvas');canvas.width=320;canvas.height=180
   const ctx=canvas.getContext('2d')!;paint=setInterval(()=>{ctx.fillStyle='#666';ctx.fillRect(0,0,320,180)},50)
   video.srcObject=canvas.captureStream(10);void video.play()
  }
  return view.select(video,()=>Boolean(video.srcObject),'synthetic-stream').id
 },
 reset:()=>telemetrySession.reset(),
 pending:()=>new ActionScope('message.send').id,
}})
