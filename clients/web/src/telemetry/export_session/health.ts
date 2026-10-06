import { ROOT_CONTEXT,SpanKind,trace } from '@opentelemetry/api'
import { diagnosticId,type TelemetrySession } from '../action_scope/session'
import type { ExportStatus } from './processor'
export function recordExportHealth(session:TelemetrySession,status:ExportStatus):void {
 const owner=session.snapshot();if(!owner.binding)return
 trace.getTracer('boohtacord/web').startSpan('telemetry.export.health',{kind:SpanKind.INTERNAL,attributes:{
  'app.schema.version':1,'session.id':owner.binding,'app.visit.id':owner.visit,'app.flow.id':diagnosticId(),
  'app.flow.name':'telemetry.export','app.flow.attempt':1,'app.flow.stage':'export',
  'app.flow.record':'checkpoint','app.flow.outcome':'unknown','app.provenance':'client_observed',
  'app.export.queued':status.queued,'app.export.accepted':status.accepted,'app.export.rejected':status.rejected,
  'app.export.dropped':status.dropped,'app.export.retried':status.retried,
  ...(status.lastAcceptedAt===null?{}:{'app.export.age_ms':Math.min(86400000,Math.max(0,Date.now()-status.lastAcceptedAt))}),
 }},ROOT_CONTEXT).end()
}
