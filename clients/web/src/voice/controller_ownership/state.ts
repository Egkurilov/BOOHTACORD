import { ref } from 'vue'
import { browserOwnershipPort } from './browser'
interface Channel { listen(handler:(value:unknown)=>void):void;send(value:unknown):void;close():void }
export interface OwnershipPort {
  hold(key:string,during:(acquired:boolean)=>Promise<void>):Promise<void>
  channel(name:string):Channel|null
  delay(ms:number):Promise<void>
}
export function createControllerOwnership(yieldMedia:()=>Promise<boolean>,port:OwnershipPort|null=browserOwnershipPort()) {
  const owned=ref(false),otherChannelId=ref<string|null>(null),ownChannelId=ref<string|null>(null)
  let account:string|null=null,channel:Channel|null=null,version=0,releaseHold:(()=>void)|null=null,held=Promise.resolve(),yielding=false
  async function release():Promise<void> {
    const current=version
    releaseHold?.();releaseHold=null
    await held
    if(current===version){owned.value=false;ownChannelId.value=null;channel?.send({type:'released'})}
  }
  function bind(next:string|null):void {
    if(next===account) return
    void release();version++;channel?.close();channel=null;account=next
    owned.value=false;ownChannelId.value=null;otherChannelId.value=null
    if(!port||!account) return
    channel=port.channel(`boohtacord:media-controller:${account}`)
    channel?.listen(value=>{
      if(!value||typeof value!=='object') return
      const message=value as {type?:unknown;channelId?:unknown}
      if(message.type==='query'&&owned.value) channel?.send({type:'owner',channelId:ownChannelId.value})
      if(message.type==='owner'&&typeof message.channelId==='string'&&message.channelId.length<=80) otherChannelId.value=message.channelId
      if(message.type==='released') otherChannelId.value=null
      if(message.type==='yield'&&owned.value&&!yielding) {
        const current=version;yielding=true
        void yieldMedia().then(async accepted=>{if(accepted&&current===version) await release()}).catch(()=>{}).finally(()=>{yielding=false})
      }
    })
    channel?.send({type:'query'})
  }
  async function acquire(target:string,current:number):Promise<boolean> {
    if(!port||!account) return true // Server lease remains authoritative when origin locking is unavailable.
    if(owned.value) return ownChannelId.value===target
    let ready!:(value:boolean)=>void
    const result=new Promise<boolean>(resolve=>{ready=resolve})
    held=port.hold(`boohtacord:media-controller:${account}`,async available=>{
      if(!available||current!==version){ready(false);return}
      owned.value=true;ownChannelId.value=target
      const hold=new Promise<void>(resolve=>{releaseHold=resolve})
      channel?.send({type:'owner',channelId:target});ready(true)
      await hold
    }).catch(()=>{ready(false);if(current===version&&owned.value){owned.value=false;ownChannelId.value=null;void yieldMedia().catch(()=>{})}})
    return result
  }
  async function claim(target:string,transfer:boolean):Promise<boolean> {
    const current=version
    if(await acquire(target,current)) return true
    if(!transfer||current!==version){channel?.send({type:'query'});return false}
    channel?.send({type:'yield'})
    for(let attempt=0;attempt<40&&current===version;attempt++) {
      await port?.delay(50)
      if(await acquire(target,current)) return true
    }
    return false
  }
  function cancel():void {bind(null)}
  return {owned,ownChannelId,otherChannelId,bind,claim,release,cancel,available:()=>Boolean(port&&account)}
}
