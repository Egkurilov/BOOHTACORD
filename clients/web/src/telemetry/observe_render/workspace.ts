import { nextTick } from 'vue'
import type { ActionScope } from '../action_scope/scope'
export async function observeWorkspace(scope:ActionScope|undefined,load:()=>Promise<void>,
 active:()=>boolean,error:()=>boolean):Promise<void> {
 try {
  scope?.step('workspace')
  await (scope?scope.within(load):load())
  if(!active()){scope?.finish('superseded','disposed');return}
  if(error()){scope?.finish('failed','dependency');return}
  await nextTick()
  if(active()){scope?.step('render');scope?.finish('success')}
  else scope?.finish('superseded','disposed')
 }catch{scope?.finish('failed','dependency')}
}
