import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import { AdminResponseError } from '../admin_request_feedback'
export interface Probe {status:'ready'|'failed'|'unknown';reason?:string;sampled_at:string|null;pending_revocations:number|null;available_bytes:number|null;total_bytes:number|null;reserved_bytes:number|null;protected_bytes:number|null;headroom_bytes:number|null}
export interface Readiness {status:'ready'|'degraded';checked_at:string;database:Probe;sfu:Probe;storage:Probe}
function probe(value:unknown):Probe {
  if(!value||typeof value!=='object') throw new Error('Нет данных зависимости.')
  const p=value as Record<string,unknown>
  if(!['ready','failed','unknown'].includes(String(p.status))||p.sampled_at!==null&&(typeof p.sampled_at!=='string'||!Number.isFinite(Date.parse(p.sampled_at)))) throw new Error('Неизвестное состояние зависимости.')
  for(const key of ['pending_revocations','available_bytes','total_bytes','reserved_bytes','protected_bytes','headroom_bytes']) if(p[key]!==null&&(typeof p[key]!=='number'||!Number.isFinite(p[key]))) throw new Error('Некорректное измерение зависимости.')
  return p as unknown as Probe
}
export async function inspectReadiness(signal?:AbortSignal,request=tracedFetch):Promise<Readiness> {
  const response=await request(`${apiBaseUrl}/admin/readiness`,{credentials:'same-origin',cache:'no-store',signal,headers:{accept:'application/json'}})
  if(!response.ok&&response.status!==503) throw new AdminResponseError(response.status)
  const value=await response.json()
  if(!value||!['ready','degraded'].includes(value.status)||typeof value.checked_at!=='string'||!Number.isFinite(Date.parse(value.checked_at))) {
    if(response.status===503) throw new AdminResponseError(503)
    throw new Error('Сервер не подтвердил готовность.')
  }
  return {status:value.status,checked_at:value.checked_at,database:probe(value.database),sfu:probe(value.sfu),storage:probe(value.storage)}
}
