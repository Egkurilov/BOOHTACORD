import { afterEach, expect, it, vi } from 'vitest'
import { startScreenClientReporting } from '../../voice/screen_client_reporter'

afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals() })

it('reports only a visible, selected stream and stops after disposal', async () => {
  vi.useFakeTimers()
  const request = vi.fn(async () => new Response(null, { status: 204 }))
  vi.stubGlobal('fetch', request)
  let visible = false
  let selected = false
  const read = vi.fn(() => selected ? {
    platform: 'desktop_web' as const, direction: 'receiver' as const,
    state: 'playing' as const,
  } : null)
  const stop = startScreenClientReporting(read, () => visible)

  await vi.advanceTimersByTimeAsync(5000)
  expect(read).not.toHaveBeenCalled()
  visible = true
  await vi.advanceTimersByTimeAsync(5000)
  expect(request).not.toHaveBeenCalled()
  selected = true
  await vi.advanceTimersByTimeAsync(5000)
  expect(request).toHaveBeenCalledOnce()
  stop()
  await vi.advanceTimersByTimeAsync(10000)
  expect(request).toHaveBeenCalledOnce()
})

it('does not overlap a slow telemetry request and resumes after it completes', async () => {
  vi.useFakeTimers()
  let complete!: (response: Response) => void
  const pending = new Promise<Response>((resolve) => { complete = resolve })
  const request = vi.fn().mockReturnValueOnce(pending).mockResolvedValue(new Response(null, { status: 204 }))
  vi.stubGlobal('fetch', request)
  const stop = startScreenClientReporting(() => ({
    platform: 'ios_web', direction: 'receiver', state: 'playing',
  }), () => true)

  await vi.advanceTimersByTimeAsync(5000)
  expect(request).toHaveBeenCalledOnce()
  await vi.advanceTimersByTimeAsync(10000)
  expect(request).toHaveBeenCalledOnce()
  complete(new Response(null, { status: 204 }))
  await vi.advanceTimersByTimeAsync(0)
  await vi.advanceTimersByTimeAsync(5000)
  expect(request).toHaveBeenCalledTimes(2)
  stop()
})
