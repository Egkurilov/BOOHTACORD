import { describe, expect, it, vi } from 'vitest'
import { context } from '@opentelemetry/api'
import { ZoneContextManager } from '@opentelemetry/context-zone'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { ActionScope } from './scope'
import { TelemetrySession } from './session'
describe('explicit user action scopes', () => {
 it('cleans all observers once even when a cleanup throws', () => {
  const action=new ActionScope('message.send'), cleaned=vi.fn()
  action.onFinish(()=>{throw new Error('synthetic cleanup')})
  action.onFinish(cleaned)
  expect(()=>action.finish('cancelled')).not.toThrow()
  action.finish('success')
  expect(cleaned).toHaveBeenCalledTimes(1)
  expect(()=>action.onFinish(()=>{throw new Error('late cleanup')})).not.toThrow()
 })
 it('isolates parallel actions, retries and exactly one terminal', async () => {
  context.setGlobalContextManager(new ZoneContextManager().enable())
  const exporter=new InMemorySpanExporter(), provider=new BasicTracerProvider({spanProcessors:[new SimpleSpanProcessor(exporter)]})
  const session=new TelemetrySession();session.bind('11111111111111111111111111111111','1')
  const a=new ActionScope('message.send',provider.getTracer('test'),session)
  const b=new ActionScope('voice.join',provider.getTracer('test'),session)
  const nested=a.within(()=>new ActionScope('voice.leave',provider.getTracer('test'),session));nested.finish('success')
  expect(nested.span.spanContext().traceId).not.toBe(a.span.spanContext().traceId)
  await Promise.all([a.within(async()=>{await Promise.resolve();a.step('ack')}),b.within(async()=>{await Promise.resolve();b.step('connect')})])
  a.finish('success');a.finish('failed');const retry=a.retry();retry.finish('timeout','deadline');b.finish('cancelled')
  const terminals=exporter.getFinishedSpans().filter(s=>s.attributes['app.flow.record']==='terminal')
  expect(terminals).toHaveLength(4)
  expect(terminals.filter(s=>s.attributes['app.flow.id']===a.id).map(s=>s.attributes['app.flow.attempt'])).toEqual([1,2])
  expect(a.id).not.toBe(b.id)
  await provider.shutdown();context.disable()
 })
 it('drops late results on account change and times out missing first frame', () => {
  vi.useFakeTimers()
  const exporter=new InMemorySpanExporter(),provider=new BasicTracerProvider({spanProcessors:[new SimpleSpanProcessor(exporter)]})
  const session=new TelemetrySession();session.bind('11111111111111111111111111111111','1')
  const old=new ActionScope('screen.view',provider.getTracer('test'),session);old.step('first_frame')
  session.reset();old.finish('success')
  const resetRetry=old.retry();expect(resetRetry.id).not.toBe(old.id);expect(resetRetry.attempt).toBe(1);resetRetry.cancel()
  const fresh=new ActionScope('screen.view',provider.getTracer('test'),session);fresh.step('first_frame')
  vi.advanceTimersByTime(120000)
  expect(exporter.getFinishedSpans().filter(s=>s.attributes['app.flow.outcome']==='success')).toHaveLength(0)
  const terminal=exporter.getFinishedSpans().find(s=>s.attributes['app.flow.outcome']==='timeout')
  expect(terminal?.attributes['app.flow.stage']).toBe('first_frame')
  vi.useRealTimers()
 })
})

