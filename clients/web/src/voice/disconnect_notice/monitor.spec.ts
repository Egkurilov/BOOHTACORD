import { expect, it, vi } from 'vitest'
const span = vi.hoisted(() => ({ addEvent: vi.fn(), setStatus: vi.fn(), end: vi.fn() }))
vi.mock('../../telemetry/client_tracing', () => ({ startTracedOperation: () => span, endTracedOperation: (value: typeof span, _name: string, failed: boolean) => { value.addEvent(failed ? 'failed' : 'completed'); value.end() } }))
import { VoiceReconnectMonitor } from '../voice_reconnect_monitor'
it('ends terminated reconnect as interrupted without a false failed outcome', async () => {
  const handlers = new Map<string, () => void>(), monitor = new VoiceReconnectMonitor()
  monitor.bind({ on: (event, listener) => { handlers.set(event, listener) } }, () => true, async () => monitor.notifyDisconnected())
  handlers.get('reconnecting')!(); await monitor.whileLeaving(async () => {})
  expect(span.addEvent).toHaveBeenCalledWith('app.client.voice.reconnect.interrupted')
  expect(span.addEvent).not.toHaveBeenCalledWith('failed')
  expect(span.end).toHaveBeenCalledTimes(1)
})
