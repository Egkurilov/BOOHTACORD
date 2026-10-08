import type { RealtimeEvent } from '../../realtime/realtime_client'
export interface SocialHint { kind:'CHANNEL'|'DIRECT_MESSAGE';conversationId:string;messageId:string;action:'reactions'|'pins' }
type Listener = (hint:SocialHint|null)=>void
const listeners = new Set<Listener>()
export const isSocialHint = (kind:string):boolean => ['message.reactions_updated','message.pins_updated','direct_message.reactions_updated'].includes(kind)
export function subscribeSocialHints(listener:Listener):()=>void { listeners.add(listener);return ()=>{listeners.delete(listener)} }
function notify(hint:SocialHint|null):void { for (const listener of listeners) { try { listener(hint) } catch { /* A disposed UI observer must not break session delivery. */ } } }
export function notifySocialRecovery():void { notify(null) }
export function notifyLocalPinChange(conversationId:string,messageId:string):void { notify({kind:'CHANNEL',conversationId,messageId,action:'pins'}) }
export function notifySocialHint(event:RealtimeEvent):void {
  if (!isSocialHint(event.kind)) return
  const direct = event.kind==='direct_message.reactions_updated'
  const conversationId = event.payload[direct?'direct_message_id':'channel_id'], messageId = event.payload.message_id
  if (typeof conversationId==='string' && typeof messageId==='string') notify({kind:direct?'DIRECT_MESSAGE':'CHANNEL',conversationId,messageId,action:event.kind==='message.pins_updated'?'pins':'reactions'})
}
