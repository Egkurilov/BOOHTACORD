import { ref } from 'vue'
export const kinds=['voice_connect','send_ack','accepted_rendered','select_first_frame','reconnect_recovered'] as const
export type JourneyKind=typeof kinds[number]
export type Outcome='completed'|'failed'|'cancelled'
export interface Observation {kind:JourneyKind;durationMs:number;outcome:Outcome}
export function createJourneyRecorder(clock=()=>performance.now()) {
  const rows=ref<Observation[]>([]),active=ref(false),pending=new Set<object>()
  let version=0,timer:ReturnType<typeof setTimeout>|null=null
  function stop():void {version++;active.value=false;pending.clear();if(timer) clearTimeout(timer);timer=null}
  function start():void {stop();rows.value=[];active.value=true;timer=setTimeout(stop,300000)}
  function begin(kind:JourneyKind):(outcome:Outcome)=>void {
    if(!active.value||pending.size>=8) return ()=>{}
    const start=clock(),current=version,token={};pending.add(token)
    return outcome=>{
      if(!pending.delete(token)||current!==version||!active.value) return
      const durationMs=clock()-start
      if(!Number.isFinite(durationMs)||durationMs<0||durationMs>300000) return
      rows.value=[...rows.value,{kind,durationMs:Math.round(durationMs*10)/10,outcome}].slice(-50)
    }
  }
  return {rows,active,start,stop,begin}
}
