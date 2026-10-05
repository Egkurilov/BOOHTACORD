import { expect,it } from 'vitest'
import { createMemberConflictState } from './conflict_state'
const account={account_id:'a',login:'user',display_name:'User',role:'MEMBER' as const,blocked:false,created_at:'date',updated_at:'v1'}
it('preserves dirty role and original revision until explicit review of current server data',()=>{
  const state=createMemberConflictState();state.sync([account]);state.drafts.a.role='ADMINISTRATOR'
  state.sync([{...account,blocked:true,updated_at:'v2'}])
  expect(state.baseline.a.updated_at).toBe('v1');expect(state.drafts.a.role).toBe('ADMINISTRATOR')
  expect(state.conflicts.a.before).toEqual({role:'MEMBER',blocked:false})
  expect(state.accept('a',false)).toBe(true);expect(state.baseline.a.updated_at).toBe('v2');expect(state.drafts.a.blocked).toBe(false)
})
it('cannot accept a conflict before refreshing, and discards only explicitly',()=>{
  const state=createMemberConflictState();state.sync([account]);state.drafts.a.blocked=true;state.capture('a')
  expect(state.accept('a',false)).toBe(false)
  state.sync([{...account,role:'ADMINISTRATOR',updated_at:'v2'}]);expect(state.accept('a',true)).toBe(true)
  expect(state.drafts.a).toEqual({role:'ADMINISTRATOR',blocked:false})
})
