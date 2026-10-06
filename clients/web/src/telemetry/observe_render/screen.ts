import { ActionScope } from '../action_scope/scope'
export function createViewObservation() {
 let current:ActionScope|null=null
 let last:ActionScope|null=null
 let video:HTMLVideoElement|null=null
 let callback:number|undefined
 let generation=0
 let intent:string|undefined
 function stop(outcome:'cancelled'|'superseded'='cancelled'):void {
  generation++;if(callback!==undefined)video?.cancelVideoFrameCallback?.(callback)
  callback=undefined;current?.finish(outcome);current=null;video=null
  if(outcome==='cancelled'){last=null;intent=undefined}
 }
 return {
  select(element:HTMLVideoElement|null,track:()=>boolean,key?:string):ActionScope {
   const previous=key!==undefined&&key===intent?last:null
   stop('superseded');video=element
   current=previous?.retry()??new ActionScope('screen.view');intent=key
   last=current
   const scope=current,version=generation
   scope.onFinish(()=>{
    if(current!==scope)return
    if(callback!==undefined)element?.cancelVideoFrameCallback?.(callback)
    callback=undefined;current=null;video=null
   })
   scope.step('select');scope.step('subscribe');scope.step('first_frame')
   const wait=()=> {
    if(version!==generation||!element||current!==scope||scope.complete)return
    if(typeof element.requestVideoFrameCallback!=='function'){scope.finish('rejected','unsupported');return}
    callback=element.requestVideoFrameCallback(()=>{
     if(version!==generation||current!==scope)return
     if(track()&&element.readyState>=2){scope.step('track');scope.step('decoded');scope.step('first_frame');scope.finish('success');current=null;callback=undefined}
     else wait()
    })
   }
   wait();return scope
  },
  fail():void {current?.finish('failed','invalid');current=null},
  stop,
 }
}

