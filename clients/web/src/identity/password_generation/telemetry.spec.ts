import { describe, expect, it } from 'vitest'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { createTracedFetch } from '../../telemetry/client_tracing'
import { register } from '../auth_client'
import { generateSecurePassword } from '../password_generator'

describe('generated password privacy', () => {
  it('sends only to authentication and never records the secret in a span', async () => {
    const password = generateSecurePassword()
    const exporter = new InMemorySpanExporter()
    const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
    let sent = false
    const transport: typeof fetch = async (_, init) => {
      sent = JSON.parse(String(init?.body)).password === password
      return new Response(null, { status: 204 })
    }
    await register({ login: 'test_member', password }, createTracedFetch(provider.getTracer('test'), transport))
    expect(sent).toBe(true)
    const records = exporter.getFinishedSpans().map(({ name, attributes, events, status }) => ({ name, attributes, events, status }))
    expect(records.length).toBe(1)
    expect(JSON.stringify(records).includes(password)).toBe(false)
    await provider.shutdown()
  })
})
