import { expect,it } from 'vitest'
import { readPins,pinMessage } from './client'
const channel='11111111-1111-4111-8111-111111111111',message='22222222-2222-4222-8222-222222222222'
it('pins are explicit administrator TEXT requests and paging has no DM endpoint',async()=>{
  let url='',method='';await pinMessage(channel,message,false,async(input,init)=>{url=String(input);method=init?.method??'';return new Response(null,{status:204})})
  expect(url).toBe(`/api/v1/admin/text-channels/${channel}/pins/${message}`);expect(method).toBe('DELETE')
  const page=await readPins(channel,undefined,async()=>new Response(JSON.stringify({pins:[{message_id:message,pinned_at:'2026-10-09T00:00:00Z',author_id:channel,preview:'<b>safe</b>',message_created_at:'2026-10-08T00:00:00Z'}],can_manage:false})))
  expect(page.pins[0].preview).toBe('<b>safe</b>');expect(page.canManage).toBe(false)
})
it('rejects invalid pin state response and surfaces permission errors',async()=>{
  await expect(readPins(channel,undefined,async()=>new Response(JSON.stringify({pins:[],can_manage:'yes'})))).rejects.toThrow()
  await expect(pinMessage(channel,message,true,async()=>new Response(null,{status:403}))).rejects.toThrow('403')
})
