import { reactive } from 'vue'
import type { AdminAccount } from '../../identity/admin_directory_client'
export type MemberDraft={role:AdminAccount['role'];blocked:boolean}
export function createMemberConflictState() {
  const drafts=reactive<Record<string,MemberDraft>>({}),baseline=reactive<Record<string,AdminAccount>>({})
  const conflicts=reactive<Record<string,{before:MemberDraft;current:AdminAccount|null}>>({})
  const state=(account:MemberDraft):MemberDraft=>({role:account.role,blocked:account.blocked})
  function sync(accounts:AdminAccount[]):void {
    for(const account of accounts) {
      const id=account.account_id,old=baseline[id],draft=drafts[id]
      if(!old||!draft){baseline[id]={...account};drafts[id]=state(account);continue}
      const dirty=JSON.stringify(state(old))!==JSON.stringify(state(draft))
      if(dirty&&old.updated_at!==account.updated_at){conflicts[id] ??= {before:state(old),current:null};conflicts[id].current={...account}}
      else if(!dirty){baseline[id]={...account};drafts[id]=state(account)}
      if(conflicts[id]) conflicts[id].current={...account}
    }
  }
  function capture(id:string):void {if(baseline[id]) conflicts[id]={before:state(baseline[id]),current:null}}
  function accept(id:string,discard:boolean):boolean {
    const current=conflicts[id]?.current
    if(!current?.updated_at) return false
    baseline[id]={...current};if(discard) drafts[id]=state(current)
    delete conflicts[id];return true
  }
  function saved(id:string,current:AdminAccount):void {baseline[id]={...current};drafts[id]=state(current);delete conflicts[id]}
  function summary(value:MemberDraft):string {return `${value.role==='ADMINISTRATOR'?'Администратор':'Пользователь'}; ${value.blocked?'заблокирован':'доступ открыт'}`}
  return {drafts,baseline,conflicts,sync,capture,accept,saved,summary}
}
