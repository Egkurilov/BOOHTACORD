import { expect, it, vi } from 'vitest'
const span = vi.hoisted(() => ({ setAttributes: vi.fn(), end: vi.fn() }))
vi.mock('@opentelemetry/api', () => ({ SpanKind: { CLIENT: 2 }, trace: { getTracer: () => ({ startSpan: () => span }) } }))
import { createVolumeReporter } from './reporting'
it('sends only closed outcomes and platform, throttling slider bursts', () => {
  const report = createVolumeReporter()
  report('success'); report('success'); report('fallback'); report('error')
  expect(span.setAttributes.mock.calls.map(([attributes]) => attributes)).toEqual([
    { 'client.platform': 'web', volume_preference_apply: 'success' },
    { 'client.platform': 'web', volume_preference_apply: 'fallback' },
    { 'client.platform': 'web', volume_preference_apply: 'error' },
  ])
  expect(span.end).toHaveBeenCalledTimes(3)
})
