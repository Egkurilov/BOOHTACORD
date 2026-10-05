import { describe, expect, it, vi } from 'vitest'
import { deliverWithRecovery } from './flow'
describe('uncertain delivery reconciliation',()=>{
  it('bounds a stalled POST and checks for a committed response',async()=>{
    const lookup=vi.fn().mockResolvedValue({id:'committed'})
    expect(await deliverWithRecovery({post:()=>new Promise(()=>{}),lookup,status:()=>{},active:()=>true,timeoutMs:5},false)).toEqual({id:'committed'})
    expect(lookup).toHaveBeenCalledOnce()
  })
  it('finds a committed send after a lost response without another POST',async()=>{
    const post=vi.fn().mockRejectedValue(new TypeError('connection lost'))
    const lookup=vi.fn().mockResolvedValue({id:'committed'}),status=vi.fn()
    expect(await deliverWithRecovery({post,lookup,status,active:()=>true},false)).toEqual({id:'committed'})
    expect(post).toHaveBeenCalledOnce();expect(lookup).toHaveBeenCalledOnce();expect(status).toHaveBeenCalledWith('checking')
  })
  it('looks up before an identical manual retry and only posts when absent',async()=>{
    const calls:string[]=[]
    await deliverWithRecovery({post:async()=>{calls.push('POST');return {id:'new'}},lookup:async()=>{calls.push('LOOKUP');return null},status:()=>{},active:()=>true},true)
    expect(calls).toEqual(['LOOKUP','POST'])
  })
  it('never blindly retries an explicit rejection or failed lookup',async()=>{
    const lookup=vi.fn(),post=vi.fn().mockRejectedValue(Object.assign(new Error('denied'),{status:403}))
    await expect(deliverWithRecovery({post,lookup,status:()=>{},active:()=>true},false)).rejects.toThrow('denied')
    expect(lookup).not.toHaveBeenCalled()
    post.mockClear();lookup.mockRejectedValue(new Error('offline'))
    await expect(deliverWithRecovery({post,lookup,status:()=>{},active:()=>true},true)).rejects.toThrow('offline');expect(post).not.toHaveBeenCalled()
  })
  it('does not post after account or screen lifecycle ends during lookup',async()=>{
    let active=true;const post=vi.fn()
    await expect(deliverWithRecovery({post,lookup:async()=>{active=false;return null},status:()=>{},active:()=>active},true)).rejects.toThrow()
    expect(post).not.toHaveBeenCalled()
  })
})
