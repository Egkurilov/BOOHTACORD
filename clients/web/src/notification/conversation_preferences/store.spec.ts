import { createPinia,setActivePinia } from 'pinia'
import { afterEach,expect,it,vi } from 'vitest'
import { useNotificationStore } from '../notification_store'
import { useDirectMessageStore } from '../../direct_message/direct_message_store'
import { messageMentionsAccount } from './mention'
import type { NotificationRuntime } from '../notification_delivery'
import type { RealtimeEvent } from '../../realtime/realtime_client'
vi.mock('./mention',()=>({messageMentionsAccount:vi.fn()}))
afterEach(()=>vi.unstubAllGlobals())
const event={kind:'direct_message.message_created',payload:{direct_message_id:'dm-a',message_id:'message-a'},eventId:'event-a',occurredAt:'2026-10-05T00:00:00Z'} satisfies RealtimeEvent
function fixture() {
  vi.stubGlobal('document',{title:'BOOHTACORD',visibilityState:'hidden'})
  setActivePinia(createPinia())
  const values=new Map<string,string>(),show=vi.fn()
  const port:NotificationRuntime={permission:()=> 'granted',requestPermission:async()=> 'granted',show,
    storage:{getItem:key=>values.get(key) ?? null,setItem:(key,value)=>{values.set(key,value)}},lock:async(_key,action)=>action()}
  const dm=useDirectMessageStore()
  dm.directMessages=[{id:'dm-a',otherParticipantId:'peer',otherParticipantDisplayName:'Участник',createdAt:event.occurredAt,unreadCount:1,mentionCount:0}]
  const store=useNotificationStore();store.start('a',port)
  return {store,dm,show,port,values}
}
it('mutes a conversation without changing protected unread or consuming seen IDs',async()=>{
  const {store,dm,show,values}=fixture();await store.enable()
  await store.setConversationPreference('DIRECT_MESSAGE','dm-a',{mode:'none',pausedUntil:0})
  await store.deliver(event,0)
  expect(show).not.toHaveBeenCalled();expect(dm.directMessages[0]?.unreadCount).toBe(1)
  expect(values.get('boohtacord:notification:a:seen')).toBeUndefined()
  store.stop()
})
it('checks exact protected mention IDs and isolates the following account',async()=>{
  const {store,show,port}=fixture();await store.enable()
  await store.setConversationPreference('DIRECT_MESSAGE','dm-a',{mode:'mentions',pausedUntil:0})
  vi.mocked(messageMentionsAccount).mockResolvedValueOnce(false)
  await store.deliver(event,0);expect(show).not.toHaveBeenCalled()
  vi.mocked(messageMentionsAccount).mockResolvedValueOnce(true)
  await store.deliver(event,0);expect(show).toHaveBeenCalledOnce()
  expect(messageMentionsAccount).toHaveBeenCalledWith(event,'a')
  store.start('b',port)
  expect(store.conversationPreference('DIRECT_MESSAGE','dm-a').mode).toBe('all')
  store.stop()
})
