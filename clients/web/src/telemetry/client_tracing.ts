import { context, SpanKind, SpanStatusCode, trace, type Span, type Tracer } from '@opentelemetry/api'
import { apiBaseUrl } from '../config/runtime'

export type OperationName = 'voice.join' | 'voice.leave' | 'voice.reconnect' | 'realtime.connect' | 'realtime.reconnect' | 'screen.share.start' | 'screen.share.stop' | 'screen.view'

function safeMethod(value: string): string {
  const method = value.toUpperCase()
  return ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'].includes(method) ? method : 'OTHER'
}

function shouldTrace(input: RequestInfo | URL): boolean {
  const base = typeof window === 'undefined' ? 'https://example.test' : window.location.origin
  const url = new URL(input instanceof Request ? input.url : String(input), base)
  if (url.origin !== base || !url.pathname.startsWith(`${apiBaseUrl}/`)) return false
  return !new Set(['/health', '/maintenance', '/auth/session', '/telemetry/traces', '/voice/screen-metrics', '/voice/rosters/events']).has(url.pathname.slice(apiBaseUrl.length))
}

export function createTracedFetch(tracer: Tracer, transport: typeof fetch): typeof fetch {
  return async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    if (!shouldTrace(input)) return transport(input, init)
    const method = safeMethod(init?.method ?? (input instanceof Request ? input.method : 'GET'))
    const span = tracer.startSpan('api.request', { kind: SpanKind.CLIENT })
    span.setAttribute('http.request.method', method)
    const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined))
    const context = span.spanContext()
    if (context.traceId !== '00000000000000000000000000000000') {
      headers.set('traceparent', `00-${context.traceId}-${context.spanId}-${(context.traceFlags & 1) ? '01' : '00'}`)
      if (context.traceState) headers.set('tracestate', context.traceState.serialize())
    }
    try {
      const response = await transport(input, { ...init, headers })
      span.setAttribute('http.response.status_code', response.status)
      if (response.status >= 500) span.setStatus({ code: SpanStatusCode.ERROR })
      return response
    } catch (cause) {
      span.setStatus({ code: SpanStatusCode.ERROR })
      throw cause
    } finally {
      span.end()
    }
  }
}

export async function traceOperation<T>(tracer: Tracer, name: OperationName, action: (within: <R>(call: () => R) => R) => Promise<T>): Promise<T> {
  const span = tracer.startSpan(name, { kind: SpanKind.CLIENT })
  const scope = trace.setSpan(context.active(), span)
  const within = <R>(call: () => R): R => context.with(scope, call)
  span.addEvent(`app.client.${name}.started`)
  try {
    const result = await within(() => action(within))
    span.addEvent(`app.client.${name}.completed`)
    return result
  } catch (cause) {
    span.setStatus({ code: SpanStatusCode.ERROR })
    span.addEvent(`app.client.${name}.failed`)
    throw cause
  } finally {
    span.end()
  }
}

export const tracedFetch: typeof fetch = (input, init) => createTracedFetch(trace.getTracer('boohtacord/web'), globalThis.fetch)(input, init)
export const tracedOperation = <T>(name: OperationName, action: (within: <R>(call: () => R) => R) => Promise<T>): Promise<T> => traceOperation(trace.getTracer('boohtacord/web'), name, action)
export function startTracedOperation(name: OperationName): Span {
  const span = trace.getTracer('boohtacord/web').startSpan(name, { kind: SpanKind.CLIENT })
  span.addEvent(`app.client.${name}.started`)
  return span
}

export function endTracedOperation(span: Span, name: OperationName, failed = false): void {
  if (failed) span.setStatus({ code: SpanStatusCode.ERROR })
  span.addEvent(`app.client.${name}.${failed ? 'failed' : 'completed'}`)
  span.end()
}

export function startTracedCompletion(name: OperationName): { finish: (failed?: boolean) => void; traceparent?: string; tracestate?: string } {
  const span = startTracedOperation(name)
  const current = span.spanContext()
  const traceparent = current.traceId === '00000000000000000000000000000000' ? undefined : `00-${current.traceId}-${current.spanId}-${(current.traceFlags & 1) ? '01' : '00'}`
  let ended = false
  const finish = (failed = false) => {
    if (ended) return
    ended = true
    endTracedOperation(span, name, failed)
  }
  return { finish, traceparent, tracestate: current.traceState?.serialize() }
}
