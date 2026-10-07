import { expect, test } from '@playwright/test'
import { counterRate, decodedP05Fps, encodedP05Fps, presentationMetrics } from './metrics'
import { isSafeLiveKitUrl } from './target'
import { baselinePlan } from './settings'

test('encoded FPS uses valid counter deltas and skips missing, reset, hidden, and invalid windows', () => {
  expect(counterRate(12, 42, 1000)).toBe(30)
  expect(counterRate(42, 3, 1000)).toBeNull()
  expect(counterRate(null, 3, 1000)).toBeNull()
  expect(counterRate(1, 2, 0)).toBeNull()
  const samples = [
    { monotonicMs: 0, visibilityState: 'visible', outbound: { layers: [{ rid: 'single', framesEncoded: 0 }] } },
    { monotonicMs: 1000, visibilityState: 'visible', outbound: { layers: [{ rid: 'single', framesEncoded: 60 }] } },
    { monotonicMs: 2000, visibilityState: 'visible', outbound: { layers: [{ rid: 'single', framesEncoded: 4 }] } },
    { monotonicMs: 3000, visibilityState: 'hidden', outbound: { layers: [{ rid: 'single', framesEncoded: 60 }] } },
  ]
  expect(encodedP05Fps(samples)).toBe(60)
  expect(encodedP05Fps([
    { ...samples[0], visibilityRevision: 1 },
    { ...samples[1], visibilityRevision: 2 },
  ])).toBeNull()
  const capped = samples.map((sample, index) => ({ ...sample, monotonicMs: index * 1000, outbound: { layers: [{ rid: 'single', framesEncoded: index * 15 }] } }))
  expect(encodedP05Fps(capped)).toBe(15)
  const decoded = capped.map(sample => ({ ...sample, inbound: { layers: [{ rid: 'single', framesDecoded: sample.monotonicMs * 30 / 1000 }] } }))
  expect(decodedP05Fps(decoded)).toBe(30)
  expect(baselinePlan).toMatchObject({ profileId: 'motion-1080p60-v1', width: 1920, height: 1080, frameRate: 60, bitrateBps: 8000000, codec: 'vp8', layers: 1 })
})

test('presentation metrics report long gaps and excess stalled-time ratio', () => {
  expect(presentationMetrics([0, 16, 32, 600, 620], 0, 1000)).toEqual({
    frameCallbacks: 5,
    presentedFrameCallbackP05Fps: 5,
    gapCountOver500Ms: 1,
    maxGapMs: 568,
    excessFreezeRatio: 0.068,
  })
})

test('LiveKit credentials are sent only to secure or loopback endpoints', () => {
  expect(isSafeLiveKitUrl('wss://isolated.example')).toBe(true)
  expect(isSafeLiveKitUrl('ws://127.0.0.1:7880')).toBe(true)
  expect(isSafeLiveKitUrl('ws://livekit.example')).toBe(false)
  expect(isSafeLiveKitUrl('https://livekit.example')).toBe(false)
})
