import { ref } from 'vue'
export function createConflictReview<T>() {
  const before=ref<T|null>(null),current=ref<T|null>(null),proposed=ref<T|null>(null),revision=ref<number|string|null>(null)
  function capture(old:T,next:T):void {before.value=structuredClone(old);proposed.value=structuredClone(next);current.value=null;revision.value=null}
  function refresh(value:T,version:number|string):void {current.value=structuredClone(value);revision.value=version}
  function reset():void {before.value=null;current.value=null;proposed.value=null;revision.value=null}
  function ready(version:number|string):boolean {return before.value!==null&&current.value!==null&&revision.value===version}
  return {before,current,proposed,revision,capture,refresh,reset,ready}
}
