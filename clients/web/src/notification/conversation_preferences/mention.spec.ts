import { afterEach,expect,it,vi } from 'vitest'
import { messageMentionsAccount } from './mention'
import { loadMessagePage } from '../../conversation/message_client'
import { loadDirectMessageHistory } from '../../direct_message/direct_message_client'
import type { RealtimeEvent } from '../../realtime/realtime_client'
vi.mock('../../conversation/message_client',()=>({loadMessagePage:vi.fn()}))
vi.mock('../../direct_message/direct_message_client',()=>({loadDirectMessageHistory:vi.fn()}))
afterEach(()=>vi.clearAllMocks())
const message={id:'message',authorId:'other',clientMessageId:'client',body:'private text',revision:1,createdAt:'2026-10-05T00:00:00Z',deleted:false,attachments:[],mentionUserIds:['me']}
const channel={kind:'message.created',payload:{channel_id:'channel',message_id:'message'},eventId:'hint',occurredAt:message.createdAt} satisfies RealtimeEvent
it('reads only the exact protected TEXT context without touching a read cursor',async()=>{
  vi.mocked(loadMessagePage).mockResolvedValue({messages:[{...message,channelId:'channel'}]})
  expect(await messageMentionsAccount(channel,'me')).toBe(true)
  expect(await messageMentionsAccount(channel,'other')).toBe(false)
  expect(loadMessagePage).toHaveBeenCalledWith('channel',undefined,undefined,'message')
})
it('uses the participant-protected DM route and never treats deleted content as a mention',async()=>{
  const event={...channel,kind:'direct_message.message_created',payload:{direct_message_id:'dm',message_id:'message'}} satisfies RealtimeEvent
  vi.mocked(loadDirectMessageHistory).mockResolvedValueOnce({messages:[{...message,directMessageId:'dm'}]})
  expect(await messageMentionsAccount(event,'me')).toBe(true)
  expect(loadDirectMessageHistory).toHaveBeenCalledWith('dm',undefined,undefined,'message')
  vi.mocked(loadDirectMessageHistory).mockResolvedValueOnce({messages:[{...message,deleted:true,directMessageId:'dm'}]})
  expect(await messageMentionsAccount(event,'me')).toBe(false)
})
it('suppresses unknown or inaccessible contexts',async()=>{
  vi.mocked(loadMessagePage).mockRejectedValueOnce(new Error('404'))
  expect(await messageMentionsAccount(channel,'me')).toBe(false)
  expect(await messageMentionsAccount({...channel,payload:{}},'me')).toBe(false)
})
