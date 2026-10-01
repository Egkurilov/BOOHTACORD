import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { ZoneContextManager } from '@opentelemetry/context-zone'
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-proto'
import { resourceFromAttributes } from '@opentelemetry/resources'
import { apiBaseUrl } from '../config/runtime'

export function initializeTracing(): void {
  const exporter = new OTLPTraceExporter({
    url: `${window.location.origin}${apiBaseUrl}/telemetry/traces`,
    headers: { 'X-Client-Platform': 'web' },
  })
  const provider = new WebTracerProvider({
    resource: resourceFromAttributes({ 'service.name': 'boohtacord-web' }),
    spanProcessors: [new BatchSpanProcessor(exporter, {
      maxExportBatchSize: 16,
      maxQueueSize: 128,
      scheduledDelayMillis: 5000,
      exportTimeoutMillis: 3000,
    })],
  })
  provider.register({ contextManager: new ZoneContextManager() })
}
