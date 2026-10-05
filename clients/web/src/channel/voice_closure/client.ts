import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
export interface Closure {phase:'open'|'revoke_pending'|'room_empty'|'finalized';admission_closed:boolean;pending_revocations:number;room_empty:boolean|null;checked_at:string;detail?:'sfu_unavailable'}
export async function inspectClosure(id:string,signal?:AbortSignal):Promise<Closure> {
  const response=await tracedFetch(`${apiBaseUrl}/admin/voice-channels/${encodeURIComponent(id)}/closure`,{credentials:'same-origin',cache:'no-store',signal,headers:{accept:'application/json'}})
  if(!response.ok) throw new Error('Состояние закрытия недоступно. Завершение не подтверждено.')
  const value=await response.json()
  if(!value||!['open','revoke_pending','room_empty','finalized'].includes(value.phase)||typeof value.admission_closed!=='boolean'||!Number.isSafeInteger(value.pending_revocations)||value.pending_revocations<0||value.room_empty!==null&&typeof value.room_empty!=='boolean'||typeof value.checked_at!=='string') throw new Error('Сервер не подтвердил состояние закрытия.')
  return value
}
