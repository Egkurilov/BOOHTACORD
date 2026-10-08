import { describe,expect,it,vi } from 'vitest'
import { createReactionBatch } from './batch'
describe('reaction metadata batches',()=>{
  it('deduplicates one scope and resolves only each message metadata',async()=>{
    const reader=vi.fn(async()=>({canPin:true,rows:[{messageId:'one',emoji:'👍' as const,count:2,mine:true}]}))
    const read=createReactionBatch(reader)
    const pages=await Promise.all([read('CHANNEL','channel','one'),read('CHANNEL','channel','one'),read('CHANNEL','channel','two')])
    expect(reader).toHaveBeenCalledOnce();expect(reader).toHaveBeenCalledWith('CHANNEL','channel',['one','two'])
    expect(pages.map(page=>page.rows.length)).toEqual([1,1,0])
  })
  it('caps every request at 100 and separates DM from TEXT',async()=>{
    const reader=vi.fn(async()=>({canPin:false,rows:[]})),read=createReactionBatch(reader)
    await Promise.all([...Array.from({length:101},(_,index)=>read('CHANNEL','scope',String(index))),read('DIRECT_MESSAGE','scope','0')])
    expect(reader.mock.calls.map(call=>(call as unknown[])[2])).toEqual([Array.from({length:100},(_,index)=>String(index)),['0'],['100']])
  })
  it('rejects every waiter on transport failure without caching failed state',async()=>{
    const reader=vi.fn().mockRejectedValueOnce(new Error('denied')).mockResolvedValue({canPin:false,rows:[]}),read=createReactionBatch(reader)
    expect((await Promise.allSettled([read('CHANNEL','scope','one'),read('CHANNEL','scope','two')])).map(result=>result.status)).toEqual(['rejected','rejected'])
    await expect(read('CHANNEL','scope','one')).resolves.toEqual({canPin:false,rows:[]});expect(reader).toHaveBeenCalledTimes(2)
  })
})
