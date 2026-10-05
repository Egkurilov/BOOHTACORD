import type { RealtimeEvent } from '../../realtime/realtime_client'
import type { NotificationRuntime } from '../notification_delivery'
import { welcomeNotice } from '../welcome_notice'
import { DEFAULT, notificationAllowed, type ConversationKind, type Preference } from './policy'
import { createConversationPreferences } from './state'
import { messageMentionsAccount } from './mention'
function scope(event:RealtimeEvent):{kind:ConversationKind;id:string}|null {
  if (event.kind==='message.created' && typeof event.payload.channel_id==='string') return {kind:'CHANNEL',id:event.payload.channel_id}
  if (event.kind==='direct_message.message_created' && typeof event.payload.direct_message_id==='string') return {kind:'DIRECT_MESSAGE',id:event.payload.direct_message_id}
  return null
}
export function createConversationNotificationController(account:string, port:NotificationRuntime, changed:()=>void) {
  const preferences=createConversationPreferences(account,port.storage)
  let active=true
  const onStorage=()=>{if(active) changed()}
  if (typeof window!=='undefined') window.addEventListener('storage',onStorage)
  const get=(kind:ConversationKind,id:string)=>preferences.get(kind,id)
  const allowed=(event:RealtimeEvent,mentioned:boolean)=>{
    const target=scope(event)
    return active && Boolean(target && notificationAllowed(get(target.kind,target.id),mentioned,Date.now()))
  }
  return {
    get,allowed,
    async set(kind:ConversationKind,id:string,value:Preference):Promise<void> {
      const write=async()=>{if(active){preferences.set(kind,id,value);changed()}}
      if (port.lock) await port.lock(`boohtacord:notification:${account}:preferences`,write)
      else await write()
    },
    async reset():Promise<void> {
      const write=async()=>{if(active){preferences.reset();changed()}}
      if (port.lock) await port.lock(`boohtacord:notification:${account}:preferences`,write)
      else await write()
    },
    async prepare(event:RealtimeEvent):Promise<{mentioned:boolean;body:string|null}|null> {
      const target=scope(event)
      if (!active || !target) return null
      const preference=get(target.kind,target.id)
      if (!notificationAllowed(preference,true,Date.now())) return null
      const mentioned=preference.mode==='mentions' ? await messageMentionsAccount(event,account) : false
      if (!allowed(event,mentioned)) return null
      return {mentioned,body:await welcomeNotice(event)}
    },
    cancel():void {active=false;if(typeof window!=='undefined') window.removeEventListener('storage',onStorage)},
  }
}
export const defaultConversationPreference=()=>({...DEFAULT})
