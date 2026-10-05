import type { OwnershipPort } from './state'
export function browserOwnershipPort():OwnershipPort|null {
  if(typeof window==='undefined'||typeof navigator==='undefined'||!navigator.locks||typeof BroadcastChannel==='undefined') return null
  return {
    hold:async(key,action)=>{await navigator.locks.request(key,{ifAvailable:true},lock=>action(Boolean(lock)))},
    channel:name=>{
      const channel=new BroadcastChannel(name)
      return {listen:handler=>{channel.onmessage=event=>handler(event.data)},send:value=>channel.postMessage(value),close:()=>channel.close()}
    },
    delay:ms=>new Promise(resolve=>setTimeout(resolve,ms)),
  }
}
