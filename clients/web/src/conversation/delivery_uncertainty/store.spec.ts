import { createPinia,setActivePinia } from 'pinia'
import { describe,it,expect,vi } from 'vitest'
import { useMessageStore } from '../message_store'
const owner='00000000-0000-4000-8000-000000000001',client='00000000-0000-4000-8000-000000000002'
const message={id:'committed',channel_id:'channel',author_id:owner,client_message_id:client,body:'fixture',created_at:'2026-10-05T00:00:00Z',revision:1,attachments:[],mention_user_ids:[]}
describe('TEXT delivery uncertainty',()=>{
 it('reconciles lost response against caller-owned receipt and exact history',async()=>{
  setActivePinia(createPinia());const store=useMessageStore();let committed=false;const calls:string[]=[]
  const request=async(path:string,init:RequestInit)=>{
   calls.push(`${init.method}:${path}`)
   if(init.method==='POST'){committed=true;throw new TypeError('lost response')}
   if(path.includes('/message-delivery/'))return new Response(JSON.stringify({account_id:owner,message_id:committed?'committed':null}))
   return new Response(JSON.stringify({messages:committed?[message]:[]}))
  }
  await store.open('channel',request)
  expect(await store.send('fixture',request,()=>client,undefined,[],owner)).toBe(true)
  expect(store.messages).toMatchObject([{id:'committed'}]);expect(calls.filter(call=>call.startsWith('POST:'))).toHaveLength(1)
 })
 it('discarding a local pending row makes no DELETE request',async()=>{
  setActivePinia(createPinia());const store=useMessageStore()
  const request=vi.fn(async(_path:string,init:RequestInit)=>new Response(JSON.stringify(init.method==='GET'?{messages:[]}:{error:{code:'VALIDATION_FAILED'}}),{status:init.method==='GET'?200:400}))
  await store.open('channel',request);await store.send('fixture',request,()=>client)
  expect(await store.remove(`optimistic:${client}`,request)).toBe(true)
  expect(store.messages).toHaveLength(0);expect(request.mock.calls.some(([,init])=>init.method==='DELETE')).toBe(false)
 })
})
