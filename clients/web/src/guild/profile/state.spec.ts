import { describe,it,expect,vi } from 'vitest'
import { createGuildProfileState } from './state'
describe('guild profile revision lifecycle',()=>{
 it('keeps fallback on initial error and accepts a later response',async()=>{
  const read=vi.fn().mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce({name:'Новая',revision:2})
  const state=createGuildProfileState(read);await state.refresh();expect(state.name.value).toBe('BOOHTACORD')
  await state.refresh();expect(state.name.value).toBe('Новая')
 })
 it('ignores old revisions and refetches hints without trusting event names',async()=>{
  const read=vi.fn().mockResolvedValueOnce({name:'Новая',revision:3}).mockResolvedValueOnce({name:'Старая',revision:2})
  const state=createGuildProfileState(read);await state.refresh(3);await state.refresh(2)
  expect(state.name.value).toBe('Новая');expect(state.revision.value).toBe(3)
 })
 it('does not apply a pending response after reset',async()=>{
  let resolve!:(value:{name:string;revision:number})=>void
  const state=createGuildProfileState(()=>new Promise(done=>{resolve=done}))
  const pending=state.refresh();state.reset();resolve({name:'Другой сервер',revision:5});await pending
  expect(state.name.value).toBe('BOOHTACORD');expect(state.loading.value).toBe(false)
 })
})
