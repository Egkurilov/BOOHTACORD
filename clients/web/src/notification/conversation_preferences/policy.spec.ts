import { describe, expect, it } from 'vitest'
import { notificationAllowed } from './policy'
import { createConversationPreferences } from './state'

function storage() {
  const values = new Map<string,string>()
  return { getItem:(key:string)=>values.get(key) ?? null, setItem:(key:string,value:string)=>{values.set(key,value)} }
}
describe('conversation notification preferences',()=>{
  it('filters modes without changing unread and resumes exactly after pause',()=>{
    expect(notificationAllowed({mode:'all',pausedUntil:0},false,100)).toBe(true)
    expect(notificationAllowed({mode:'mentions',pausedUntil:0},false,100)).toBe(false)
    expect(notificationAllowed({mode:'mentions',pausedUntil:0},true,100)).toBe(true)
    expect(notificationAllowed({mode:'none',pausedUntil:0},true,100)).toBe(false)
    expect(notificationAllowed({mode:'all',pausedUntil:101},true,100)).toBe(false)
    expect(notificationAllowed({mode:'all',pausedUntil:101},true,101)).toBe(true)
  })
  it('isolates accounts and shares the latest bounded metadata across tabs',()=>{
    const port=storage(), first=createConversationPreferences('a',port), second=createConversationPreferences('a',port)
    first.set('CHANNEL','chat',{mode:'none',pausedUntil:0})
    expect(second.get('CHANNEL','chat').mode).toBe('none')
    expect(second.get('DIRECT_MESSAGE','chat').mode).toBe('all')
    expect(createConversationPreferences('b',port).get('CHANNEL','chat').mode).toBe('all')
    for(let i=0;i<99;i++) first.set('CHANNEL',`chat-${i}`,{mode:'mentions',pausedUntil:0})
    expect(()=>first.set('CHANNEL','overflow',{mode:'none',pausedUntil:0})).toThrow()
    expect(second.get('CHANNEL','chat').mode).toBe('none')
    first.set('CHANNEL','chat',{mode:'all',pausedUntil:0})
    expect(()=>first.set('CHANNEL','overflow',{mode:'none',pausedUntil:0})).not.toThrow()
  })
  it('fails closed for corrupt persisted settings and rejects invalid writes',()=>{
    const port=storage(); port.setItem('boohtacord:notification:a:conversations:v1','invalid')
    const preferences=createConversationPreferences('a',port)
    expect(preferences.get('CHANNEL','chat').mode).toBe('none')
    expect(()=>preferences.set('CHANNEL','chat',{mode:'all',pausedUntil:NaN})).toThrow()
  })
})
