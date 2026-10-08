import { validField } from '../flow_contract/validate'
export function diagnosticId(): string { return crypto.randomUUID().replaceAll('-','') }
export interface SessionSnapshot { generation: number; visit: string; binding: string | null; media: string | null; leaseId: string | null; mediaFlow?:string|null }
export class TelemetrySession {
 private generation = 0
 private visit = diagnosticId()
 private binding: string | null = null
 private media: string | null = null
 private leaseId: string | null = null
 private mediaFlow:string|null=null
 private listeners = new Set<() => void>()
 snapshot(): SessionSnapshot { return {generation:this.generation,visit:this.visit,binding:this.binding,media:this.media,leaseId:this.leaseId,mediaFlow:this.mediaFlow} }
 current(snapshot: SessionSnapshot): boolean { return snapshot.generation === this.generation && snapshot.binding === this.binding }
 reset(): void { this.generation++; this.visit=diagnosticId(); this.binding=null; this.media=null;this.leaseId=null;this.mediaFlow=null; this.listeners.forEach(f=>f()) }
 bind(id: string | null, schema: string | null): void {
  if (schema !== '1' || !validField('session.id',id)) return
  if (this.binding && this.binding !== id) this.reset()
  this.binding=id
 }
 beginMedia(): string { this.media=diagnosticId();this.mediaFlow=diagnosticId(); return this.media }
 bindMediaLease(id:string):boolean {
  const compact=id.toLowerCase().replaceAll('-','')
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id) || !validField('app.media.session.id',compact))return false
  this.leaseId=id.toLowerCase();this.media=compact;return true
 }
 bindMediaFlow(id:string):void {if(validField('app.flow.id',id))this.mediaFlow=id}
 endMedia(): void { this.media=null;this.leaseId=null;this.mediaFlow=null }
 onReset(listener: () => void): () => void { this.listeners.add(listener); return ()=>this.listeners.delete(listener) }
}
export const telemetrySession = new TelemetrySession()

