import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { ZoneContextManager } from '@opentelemetry/context-zone'
import { SessionProcessor } from './export_session/processor'
import { resourceFromAttributes } from '@opentelemetry/resources'
import { AlwaysOffSampler,ParentBasedSampler,TraceIdRatioBasedSampler } from '@opentelemetry/sdk-trace-base'

export function initializeTracing(): void {
  const configured=Number(import.meta.env.VITE_TRACE_SAMPLE_RATIO??1)
  const ratio=import.meta.env.VITE_TELEMETRY_ENABLED==='false'?0:Number.isFinite(configured)&&configured>=0&&configured<=1?configured:1
  const provider = new WebTracerProvider({
    sampler:import.meta.env.VITE_TELEMETRY_ENABLED==='false'?new AlwaysOffSampler():new ParentBasedSampler({root:new TraceIdRatioBasedSampler(ratio)}),
    resource: resourceFromAttributes({ 'service.name': 'boohtacord-web' }),
    spanProcessors: [new SessionProcessor()],
  })
  provider.register({ contextManager: new ZoneContextManager() })
}
