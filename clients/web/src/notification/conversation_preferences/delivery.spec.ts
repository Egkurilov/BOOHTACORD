import { expect, it, vi } from 'vitest'
import { createNotificationDelivery, type NotificationRuntime } from '../notification_delivery'

it('rechecks conversation filters inside a delayed native lock without consuming the event',async()=>{
  const values=new Map<string,string>(), show=vi.fn()
  let release!:()=>void, entered!:()=>void, allowed=true
  const held=new Promise<void>(resolve=>{release=resolve}), locked=new Promise<void>(resolve=>{entered=resolve})
  const runtime:NotificationRuntime={permission:()=> 'granted',requestPermission:async()=> 'granted',show,
    storage:{getItem:key=>values.get(key) ?? null,setItem:(key,value)=>{values.set(key,value)}},
    lock:async(_key,action)=>{entered();await held;return action()}}
  const delivery=createNotificationDelivery('a',runtime);await delivery.enable()
  const pending=delivery.deliver('event','Новое сообщение в канале.',()=>allowed)
  await locked;allowed=false;release();await pending
  expect(show).not.toHaveBeenCalled()
  expect(values.get('boohtacord:notification:a:seen')).toBeUndefined()
  allowed=true;await delivery.deliver('event','Новое сообщение в канале.',()=>allowed)
  expect(show).toHaveBeenCalledOnce()
})
