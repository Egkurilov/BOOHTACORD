import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { MessageRequest } from '../message_client'
export interface Pin {messageId:string;pinnedAt:string;authorId:string;preview:string;messageCreatedAt:string}
export interface PinPage {pins:Pin[];nextCursor?:string;canManage:boolean}
const validID = (value:unknown):value is string => typeof value==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
export async function readPins(channel:string,before?:string,request:MessageRequest=tracedFetch):Promise<PinPage> {
  if (!validID(channel) || before!==undefined && (!before || before.length>256)) throw new Error('Некорректный список закреплений.')
  const response=await request(`${apiBaseUrl}/channels/${encodeURIComponent(channel)}/pins${before?`?before=${encodeURIComponent(before)}`:''}`,{method:'GET',credentials:'same-origin',headers:{accept:'application/json'}})
  if (!response.ok) throw new Error(`Не удалось получить закрепления (${response.status}).`)
  const page=await response.json() as {pins?:unknown;next_cursor?:unknown;can_manage?:unknown}
  if (!page || !Array.isArray(page.pins) || page.pins.length>50 || typeof page.can_manage!=='boolean' || page.next_cursor!==undefined && (typeof page.next_cursor!=='string' || !page.next_cursor || page.next_cursor.length>256)) throw new Error('Сервер вернул некорректные закрепления.')
  const seen=new Set<string>()
  const pins:Pin[]=page.pins.map(pin=>{
    if (!pin || !validID(pin.message_id) || !validID(pin.author_id) || seen.has(pin.message_id) || typeof pin.preview!=='string' || Array.from(pin.preview).length>240 || !Number.isFinite(Date.parse(pin.pinned_at)) || !Number.isFinite(Date.parse(pin.message_created_at))) throw new Error('Сервер вернул некорректное закрепление.')
    seen.add(pin.message_id);return {messageId:pin.message_id,pinnedAt:pin.pinned_at,authorId:pin.author_id,preview:pin.preview,messageCreatedAt:pin.message_created_at}
  })
  return {pins,nextCursor:page.next_cursor as string|undefined,canManage:page.can_manage}
}
export async function pinMessage(channel:string,message:string,present:boolean,request:MessageRequest=tracedFetch):Promise<void> {
  if (!validID(channel) || !validID(message) || typeof present!=='boolean') throw new Error('Некорректное закрепление.')
  const response=await request(`${apiBaseUrl}/admin/text-channels/${encodeURIComponent(channel)}/pins/${encodeURIComponent(message)}`,{method:present?'PUT':'DELETE',credentials:'same-origin',headers:{accept:'application/json'}})
  if (response.status!==204) throw new Error(`Не удалось изменить закрепление (${response.status}). Обновите список перед повтором.`)
}
