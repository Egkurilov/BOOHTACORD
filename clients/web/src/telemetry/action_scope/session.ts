import { validField } from '../flow_contract/validate'
export function diagnosticId(): string { return crypto.randomUUID().replaceAll('-','') }
export interface SessionSnapshot { generation: number; visit: string; binding: string | null; media: string | null; mediaFlow?:string|null }
export class TelemetrySession {
 private generation = 0
 private visit = diagnosticId()
 private binding: string | null = null
 private media: string | null = null
 private mediaFlow:string|null=null
 private listeners = new Set<() => void>()
 snapshot(): SessionSnapshot { return {generation:this.generation,visit:this.visit,binding:this.binding,media:this.media,mediaFlow:this.mediaFlow} }
 current(snapshot: SessionSnapshot): boolean { return snapshot.generation === this.generation && snapshot.binding === this.binding }
 reset(): void { this.generation++; this.visit=diagnosticId(); this.binding=null; this.media=null;this.mediaFlow=null; this.listeners.forEach(f=>f()) }
 bind(id: string | null, schema: string | null): void {
  if (schema !== '1' || !validField('session.id',id)) return
  if (this.binding && this.binding !== id) this.reset()
  this.binding=id
 }
 beginMedia(): string { this.media=diagnosticId();this.mediaFlow=diagnosticId(); return this.media }
 bindMediaFlow(id:string):void {if(validField('app.flow.id',id))this.mediaFlow=id}
 endMedia(): void { this.media=null;this.mediaFlow=null }
 onReset(listener: () => void): () => void { this.listeners.add(listener); return ()=>this.listeners.delete(listener) }
}
export const telemetrySession = new TelemetrySession()

