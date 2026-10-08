import { describe, expect, it } from 'vitest'
import { readReactions, setReaction } from './client'
const channel='11111111-1111-4111-8111-111111111111',message='22222222-2222-4222-8222-222222222222'
describe('bounded exact reaction contract',()=>{
  it('reads count/mine without actors and refuses foreign rows',async()=>{
    const page=await readReactions('CHANNEL',channel,[message],async()=>new Response(JSON.stringify({reactions:[{message_id:message,emoji:'❤️',count:2,mine:true}],can_pin:false})))
    expect(page.rows[0]).toEqual({messageId:message,emoji:'❤️',count:2,mine:true})
    await expect(readReactions('CHANNEL',channel,[message],async()=>new Response(JSON.stringify({reactions:[{message_id:channel,emoji:'👍',count:1,mine:false}],can_pin:false})))).rejects.toThrow()
  })
  it('uses explicit PUT/DELETE in the correct private scope with no body',async()=>{
    const calls:{url:string;init?:RequestInit}[]=[]
    const request=async(url:RequestInfo|URL,init?:RequestInit)=>{calls.push({url:String(url),init});return new Response(null,{status:204})}
    await setReaction('DIRECT_MESSAGE',channel,message,'✅',true,request);await setReaction('DIRECT_MESSAGE',channel,message,'✅',false,request)
    expect(calls.map(call=>call.init?.method)).toEqual(['PUT','DELETE'])
    expect(calls[0].url).toContain(`/direct-messages/${channel}/messages/${message}/reactions/`)
    expect(calls.every(call=>call.init?.credentials==='same-origin'&&call.init.body===undefined)).toBe(true)
  })
  it('rejects unsupported emoji/unbounded input before fetch',async()=>{
    let calls=0;const request=async()=>{calls++;return new Response()}
    await expect(setReaction('CHANNEL',channel,message,'😀' as never,true,request)).rejects.toThrow()
    await expect(readReactions('CHANNEL',channel,Array.from({length:101},()=>message),request)).rejects.toThrow()
    expect(calls).toBe(0)
  })
})
