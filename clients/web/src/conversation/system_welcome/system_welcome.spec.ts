import { describe,it,expect } from 'vitest'
import { loadMessagePage } from '../message_client'
import { groupChronologicalMessages } from '../message_grouping'
import { createMessageLogAnnouncer } from '../message_log_announcement'
describe('system welcome messages',()=>{
 const row={id:'message',channel_id:'channel',author_id:'member',client_message_id:'client',body:'врывается в гильдию.',created_at:'2026-10-05T00:00:00Z',revision:1,deleted:false,attachments:[],mention_user_ids:['member'],kind:'SYSTEM_WELCOME'}
 it('preserves explicit system kind in history',async()=>{
  const page=await loadMessagePage('channel',undefined,async()=>new Response(JSON.stringify({messages:[row]})))
  expect(page.messages[0].kind).toBe('SYSTEM_WELCOME')
 })
 it('rejects unknown kinds',async()=>{
  await expect(loadMessagePage('channel',undefined,async()=>new Response(JSON.stringify({messages:[{...row,kind:'FAKE'}]})))).rejects.toThrow()
 })
 it('never groups adjacent system rows with user rows',()=>{
  const message={authorId:'member',createdAt:row.created_at};const grouped=groupChronologicalMessages([{message},{message:{...message,kind:'SYSTEM_WELCOME'}}])
  expect(grouped[1].grouped).toBe(false)
 })
 it('announces a neutral new participant message',()=>{
  const announce=createMessageLogAnnouncer();const update={conversationId:'channel',loaded:true,active:true,ownId:'owner',displayName:()=> 'Private',messages:[] as {id:string;authorId:string;createdAt:string;kind:string}[]}
  announce(update);expect(announce({...update,messages:[{id:'new',authorId:'member',createdAt:row.created_at,kind:'SYSTEM_WELCOME'}]})).toBe('Новый участник в гильдии.')
 })
})
