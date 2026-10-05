import { expect,it,vi } from 'vitest'
import { createControllerOwnership,type OwnershipPort } from './state'
function fixture() {
  const held=new Set<string>(), listeners=new Map<string,Set<(value:unknown)=>void>>()
  const port:OwnershipPort={
    hold:async(key,action)=>{if(held.has(key)) return action(false);held.add(key);try{await action(true)}finally{held.delete(key)}},
    channel:name=>{let own:((value:unknown)=>void)|null=null;return {
      listen:handler=>{own=handler;const set=listeners.get(name) ?? new Set();set.add(handler);listeners.set(name,set)},
      send:value=>{for(const listener of listeners.get(name) ?? []) if(listener!==own) queueMicrotask(()=>listener(value))},
      close:()=>{if(own) listeners.get(name)?.delete(own)},
    }},delay:async()=>{await new Promise(resolve=>setTimeout(resolve,1))},
  }
  return {port,held}
}
it('keeps one origin controller; a normal join and cancellation never yield ownership',async()=>{
  const {port}=fixture(), yieldFirst=vi.fn(async()=>true)
  const first=createControllerOwnership(yieldFirst,port),second=createControllerOwnership(async()=>true,port)
  first.bind('account');second.bind('account')
  expect(await first.claim('voice-a',false)).toBe(true)
  expect(await second.claim('voice-b',false)).toBe(false)
  expect(yieldFirst).not.toHaveBeenCalled()
  expect(first.owned.value).toBe(true)
  await first.release();await second.release();first.cancel();second.cancel()
})
it('requires explicit transfer, yields once and holds exactly one replacement controller',async()=>{
  const {port,held}=fixture(), yielding=vi.fn(async()=>true)
  const first=createControllerOwnership(yielding,port),second=createControllerOwnership(async()=>true,port)
  first.bind('account');second.bind('account');await first.claim('voice-a',false)
  expect(await second.claim('voice-b',true)).toBe(true)
  expect(yielding).toHaveBeenCalledOnce();expect(first.owned.value).toBe(false)
  expect(second.owned.value).toBe(true);expect(held.size).toBe(1)
  await first.release();await second.release();first.cancel();second.cancel()
})
it('drops stale ownership when an account is switched during a pending claim',async()=>{
  let grant!:()=>void
  const port:OwnershipPort={hold:async(_key,action)=>{await new Promise<void>(resolve=>{grant=resolve});await action(true)},channel:()=>null,delay:async()=>{}}
  const controller=createControllerOwnership(async()=>true,port)
  controller.bind('a');const pending=controller.claim('voice',false);controller.bind('b');grant()
  expect(await pending).toBe(false);expect(controller.owned.value).toBe(false);controller.cancel()
})

it('does not release an owner whose media cleanup failed',async()=>{
  const {port,held}=fixture(),yielding=vi.fn(async()=>false)
  const first=createControllerOwnership(yielding,port),second=createControllerOwnership(async()=>true,port)
  first.bind('account');second.bind('account');await first.claim('voice-a',false)
  expect(await second.claim('voice-b',true)).toBe(false)
  expect(yielding).toHaveBeenCalledOnce();expect(first.owned.value).toBe(true);expect(held.size).toBe(1)
  await first.release();await second.release();first.cancel();second.cancel()
})
