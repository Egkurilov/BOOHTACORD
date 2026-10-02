import { describe, expect, it, vi } from 'vitest'
import type { LocalAudioTrack } from 'livekit-client'
import { LiveKitMicrophoneAdapter } from './livekit_microphone_adapter'
import type { AudioProcessingOptions } from './types'
const browser: AudioProcessingOptions = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'browser' }
const rnnoise = { ...browser, noiseSuppressionMode: 'rnnoise' } as const
function fixture() {
  const source = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: true }) }
  const processed = { enabled: true }
  const events: string[] = []
  const track = {
    mediaStreamTrack: source,
    mute: vi.fn(async () => { events.push('mute'); source.enabled = false; processed.enabled = false }),
    unmute: vi.fn(async () => { events.push('unmute'); source.enabled = true }),
    stop: vi.fn(() => source.stop()),
    applyConstraints: vi.fn(async () => undefined),
    restartTrack: vi.fn(async () => undefined),
    setProcessor: vi.fn(async () => { events.push('process'); track.mediaStreamTrack = processed as typeof source }),
    stopProcessor: vi.fn(async () => { track.mediaStreamTrack = source; events.push('destroy') }),
  }
  const processor = { processedTrack: processed, name: 'test', mute: vi.fn(), unmute: vi.fn(), destroy: vi.fn(), init: vi.fn() }
  const dependencies = {
    createTrack: vi.fn(async () => track as unknown as LocalAudioTrack),
    publishTrack: vi.fn(async () => { events.push(`publish:${source.enabled}`) }),
    unpublishTrack: vi.fn(async () => undefined),
    createProcessor: vi.fn((_callbacks: unknown) => processor as never),
  }
  const adapter = new LiveKitMicrophoneAdapter(dependencies)
  return { adapter, dependencies, track, processor, source, events }
}
describe('single microphone lifecycle owner', () => {
  it('listener and muted intent do not acquire capture', async () => {
    const f = fixture()
    await f.adapter.setEnabled(false, browser)
    await f.adapter.setProcessing(rnnoise)
    expect(f.dependencies.createTrack).not.toHaveBeenCalled()
  })
  it('sets the processor before publishing and reads settings from the original source', async () => {
    const f = fixture()
    await f.adapter.setEnabled(true, rnnoise)
    expect(f.events.indexOf('process')).toBeLessThan(f.events.indexOf('publish:false'))
    expect(f.adapter.readCaptureSettings()).toEqual({ noiseSuppression: true })
  })
  it('respects mute that arrives during pending processor initialization before publish', async () => {
    const f = fixture()
    let finish!: () => void
    f.track.setProcessor.mockImplementation(async () => new Promise<void>((resolve) => { finish = resolve }))
    const enabling = f.adapter.setEnabled(true, rnnoise)
    await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
    const muting = f.adapter.setEnabled(false, rnnoise)
    finish()
    await Promise.all([enabling, muting])
    expect(f.events).toContain('publish:false')
    expect(f.track.unmute).not.toHaveBeenCalled()
    expect(f.source.enabled).toBe(false)
  })
  it('revokes a pending initializer immediately and never publishes a stale track', async () => {
    const f = fixture()
    let finish!: () => void
    f.track.setProcessor.mockImplementation(async () => new Promise<void>((resolve) => { finish = resolve }))
    const enabling = f.adapter.setEnabled(true, rnnoise)
    await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
    const disposing = f.adapter.dispose()
    expect(f.source.enabled).toBe(false)
    finish()
    await expect(enabling).rejects.toThrow()
    await disposing
    expect(f.dependencies.publishTrack).not.toHaveBeenCalled()
    expect(f.track.stop).toHaveBeenCalledOnce()
  })
  it('keeps requested RNNoise while falling back and does not mistake missing settings for browser success', async () => {
    const f = fixture()
    f.track.setProcessor.mockRejectedValue(new Error('load'))
    f.source.getSettings = () => ({}) as never
    await f.adapter.setEnabled(true, rnnoise)
    expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'unknown', status: 'fallback', fallbackReason: 'processor-error' })
    expect(f.track.applyConstraints).toHaveBeenLastCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  })
  it('rolls constraints back and retains requested preferences if applying a profile fails', async () => {
    const f = fixture()
    await f.adapter.setEnabled(true, browser)
    f.track.applyConstraints.mockRejectedValueOnce(new Error('constraints'))
    await expect(f.adapter.setProcessing({ ...browser, noiseSuppressionMode: 'off' })).rejects.toThrow('constraints')
    expect(f.adapter.runtimeState.requestedMode).toBe('browser')
    expect(f.track.applyConstraints).toHaveBeenLastCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  })
  it('keeps device replacement inside the same serialized lifecycle', async () => {
    const f = fixture()
    await f.adapter.setEnabled(true, rnnoise)
    await f.adapter.switchDevice('device-local')
    expect(f.track.restartTrack).toHaveBeenCalledWith(expect.objectContaining({ deviceId: { exact: 'device-local' }, noiseSuppression: false }))
    expect(f.adapter.readCaptureSettings()).toEqual({ noiseSuppression: true })
  })
  it('does not create extra tracks and releases every graph over 100 mode transitions', async () => {
    const f = fixture()
    await f.adapter.setEnabled(true, browser)
    for (let i = 0; i < 100; i++) {
      await f.adapter.setProcessing(rnnoise)
      await f.adapter.setEnabled(false, rnnoise)
      await f.adapter.setProcessing(browser)
      await f.adapter.setEnabled(true, browser)
    }
    await f.adapter.dispose()
    expect(f.dependencies.createTrack).toHaveBeenCalledOnce()
    expect(f.track.setProcessor).toHaveBeenCalledTimes(100)
    expect(f.track.stopProcessor).toHaveBeenCalledTimes(100)
    expect(f.track.stop).toHaveBeenCalledOnce()
  })
})


it('recovers a running processor failure without changing requested preference or mute intent', async () => {
  const f = fixture()
  await f.adapter.setEnabled(true, rnnoise)
  await f.adapter.setEnabled(false, rnnoise)
  const callbacks = f.dependencies.createProcessor.mock.calls[0][0] as { onFailure(reason: 'overload'): void }
  callbacks.onFailure('overload')
  await vi.waitFor(() => expect(f.adapter.runtimeState.status).toBe('fallback'))
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'browser', fallbackReason: 'overload' })
  expect(f.source.enabled).toBe(false)
})
it('leaves microphone safely muted if running processor recovery cannot apply browser constraints', async () => {
  const f = fixture()
  await f.adapter.setEnabled(true, rnnoise)
  f.track.applyConstraints.mockRejectedValue(new Error('recovery failed'))
  const callbacks = f.dependencies.createProcessor.mock.calls[0][0] as { onFailure(reason: 'processor-error'): void }
  callbacks.onFailure('processor-error')
  await vi.waitFor(() => expect(f.adapter.runtimeState.status).toBe('error'))
  expect(f.source.enabled).toBe(false)
  expect(f.adapter.runtimeState.effectiveMode).toBe('unknown')
})


it('falls back if a processor resolves initialization without a derived output', async () => {
  const f = fixture()
  f.processor.processedTrack = undefined as never
  await f.adapter.setEnabled(true, rnnoise)
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'browser', status: 'fallback' })
})


it('retains RNNoise preference and applies browser fallback when the build disables it', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'false')
  try {
    const f = fixture()
    await f.adapter.setEnabled(true, rnnoise)
    expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
    expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'release-disabled' })
    expect(f.track.applyConstraints).toHaveBeenLastCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  } finally { vi.unstubAllEnvs() }
})
