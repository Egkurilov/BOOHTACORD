import { mediaSampleChunks } from './chunks'
import { SpanKind, trace } from '@opentelemetry/api'
import { validField } from '../flow_contract/validate'
import { telemetrySession,type SessionSnapshot } from '../action_scope/session'
const metrics:Record<string,string>={encoded_fps:'encoded_fps',decoded_fps:'decoded_fps',
 presented_fps:'presented_fps',rtt_ms:'rtt_ms',jitter_ms:'jitter_ms',packet_loss_percent:'loss_percent',target_fps:'target_fps'}
export function sampleAttributes(report:Record<string,unknown>):Record<string,string|number>{
 const age=report.sample_age_ms,state=!validField('app.sample.age_ms',age)?'unknown':(age as number)>15000?'stale':'fresh'
 const attrs:Record<string,string|number>={'app.media.sample_state':state,
  'app.media.direction':report.direction==='receiver'?'receiver':'sender','app.media.source':'webrtc'}
 if(validField('app.sample.age_ms',age))attrs['app.sample.age_ms']=age as number
 if(state!=='fresh')return attrs
 const extended=['total_bitrate_kbps','selected_layer_bitrate_kbps','retransmitted_bitrate_kbps','encode_ms_per_frame','decode_ms_per_frame','jitter_buffer_ms_per_frame','nack_per_second','pli_per_second','fir_per_second','first_frame_ms','freeze_duration_ms','freeze_count','stats_window_ms','stats_source','presentation_source','collection_state']
 for(const key of extended)if(validField('app.media.'+key,report[key]))attrs['app.media.'+key]=report[key] as string|number
 for(const [from,to] of Object.entries(metrics))if(validField('app.media.'+to,report[from]))attrs['app.media.'+to]=report[from] as number
 const bitrate=typeof report.bitrate_kbps==='number'?report.bitrate_kbps*1000:undefined
 if(validField('app.media.bitrate_bps',bitrate))attrs['app.media.bitrate_bps']=bitrate!
 if(validField('app.sample.window_ms',report.packet_loss_window_ms))attrs['app.sample.window_ms']=report.packet_loss_window_ms as number
 if(validField('app.media.adaptation_reason',report.adaptation_reason))attrs['app.media.adaptation_reason']=report.adaptation_reason as string
 return attrs
}
export function recordMediaSample(report:Record<string,unknown>,owner:SessionSnapshot):void {
 const now=telemetrySession.snapshot()
 if(!owner.binding||!owner.media||!owner.mediaFlow||!telemetrySession.current(owner)||owner.media!==now.media)return
 const core:Record<string,string|number>={'app.schema.version':1,'session.id':owner.binding,'app.visit.id':owner.visit,
  'app.flow.id':owner.mediaFlow,'app.flow.name':'voice.join','app.flow.attempt':1,'app.flow.stage':'track',
  'app.flow.record':'checkpoint','app.flow.outcome':'unknown','app.provenance':'client_observed','app.media.session.id':owner.media}
 const sampled=sampleAttributes(report),presented=sampled['app.media.presented_fps'];delete sampled['app.media.presented_fps']
 for(const attrs of mediaSampleChunks(core,sampled))trace.getTracer('boohtacord/web').startSpan('media.sample',{kind:SpanKind.INTERNAL,attributes:attrs}).end()
 if(presented!==undefined)trace.getTracer('boohtacord/web').startSpan('media.sample',{kind:SpanKind.INTERNAL,
  attributes:{...core,'app.media.direction':sampled['app.media.direction'],'app.media.sample_state':sampled['app.media.sample_state'],
   'app.sample.age_ms':sampled['app.sample.age_ms'],'app.media.presentation_source':sampled['app.media.presentation_source'],'app.media.source':'presentation','app.media.presented_fps':presented}}).end()
}
