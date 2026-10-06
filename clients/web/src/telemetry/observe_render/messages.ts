import { toRaw } from 'vue'
import { ActionScope } from '../action_scope/scope'
import { failureOutcome } from '../action_scope/failure'
const rendered=new WeakMap<object,Map<ActionScope,()=>void>>()
export function awaitMessageRender(message:object,scope:ActionScope,finish=()=>scope.finish('success')):void {
 scope.step('ack');scope.step('render');const raw=toRaw(message),waiting=rendered.get(raw)??new Map()
 waiting.set(scope,finish);rendered.set(raw,waiting)
 scope.onFinish(()=>waiting.delete(scope))
}
export function observeMessageRender(message:object):void {
 const raw=toRaw(message),waiting=rendered.get(raw);if(waiting){rendered.delete(raw);for(const finish of waiting.values())finish()}
}
export function createSendObservation() {
 const intents=new Map<string,ActionScope>()
 return {
  begin(id:string):ActionScope {const previous=intents.get(id),scope=previous?previous.retry():new ActionScope('message.send');intents.set(id,scope);scope.step('request');return scope},
  acknowledged(id:string,message:object):void {const scope=intents.get(id);if(scope){awaitMessageRender(message,scope);intents.delete(id)}},
  failed(id:string,cause?:unknown):void {const failure=failureOutcome(cause);intents.get(id)?.finish(failure.outcome,failure.reason)},
  discard(id:string):void {intents.get(id)?.cancel();intents.delete(id)},
  close():void {for(const scope of intents.values())scope.finish('superseded','disposed');intents.clear()},
 }
}

