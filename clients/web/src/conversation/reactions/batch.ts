import { readReactions, type ReactionKind, type ReactionPage } from './client'
type Waiter = {id:string;resolve:(page:ReactionPage)=>void;reject:(reason:unknown)=>void}
type Batch = {kind:ReactionKind;conversation:string;waiters:Waiter[]}
export function createReactionBatch(reader = readReactions) {
  const pending = new Map<string,Batch>()
  async function flush(key:string,batch:Batch): Promise<void> {
    pending.delete(key)
    const ids = [...new Set(batch.waiters.map(item=>item.id))]
    try {
      for (let offset=0;offset<ids.length;offset+=100) {
        const chunk = ids.slice(offset,offset+100), wanted = new Set(chunk)
        const page = await reader(batch.kind,batch.conversation,chunk)
        for (const waiter of batch.waiters) if (wanted.has(waiter.id)) waiter.resolve({rows:page.rows.filter(row=>row.messageId===waiter.id),canPin:page.canPin})
      }
    } catch (reason) { for (const waiter of batch.waiters) waiter.reject(reason) }
  }
  return (kind:ReactionKind,conversation:string,id:string):Promise<ReactionPage> => new Promise((resolve,reject)=>{
    const key = `${kind}:${conversation}`
    let batch = pending.get(key)
    if (!batch) { batch={kind,conversation,waiters:[]};pending.set(key,batch);const own=batch;queueMicrotask(()=>{void flush(key,own)}) }
    batch.waiters.push({id,resolve,reject})
  })
}
export const readReactionFor = createReactionBatch()
