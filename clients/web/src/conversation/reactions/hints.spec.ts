import { describe,expect,it,vi } from 'vitest'
import { notifySocialHint,notifySocialRecovery,subscribeSocialHints } from './hints'
describe('social invalidations',()=>{
  it('dispatches DM scoped IDs without participants and releases observers',()=>{
    const listener=vi.fn(),stop=subscribeSocialHints(listener)
    notifySocialHint({eventId:'event',occurredAt:'2026-10-09T12:00:00Z',kind:'direct_message.reactions_updated',payload:{direct_message_id:'pair',message_id:'message'}})
    expect(listener).toHaveBeenCalledWith({kind:'DIRECT_MESSAGE',conversationId:'pair',messageId:'message',action:'reactions'})
    notifySocialRecovery();expect(listener).toHaveBeenLastCalledWith(null)
    stop();notifySocialRecovery();expect(listener).toHaveBeenCalledTimes(2)
  })
  it('isolates a failing observer from delivery',()=>{
    const stopBad=subscribeSocialHints(()=>{throw Error('disposed')}),listener=vi.fn(),stop=subscribeSocialHints(listener)
    expect(()=>notifySocialRecovery()).not.toThrow();expect(listener).toHaveBeenCalledWith(null)
    stopBad();stop()
  })
})
