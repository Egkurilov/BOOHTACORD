import { readFileSync } from 'node:fs'
import { expect, test } from '@playwright/test'
import { decodedP05Fps, encodedP05Fps, frameSequenceMetrics, presentationMetrics } from './baseline/metrics'
import { isSafeLiveKitUrl } from './baseline/target'
import { baselinePlan, measurementPlan } from './baseline/settings'

const livekitUrl = process.env.SCREEN_BASELINE_LIVEKIT_URL
const publisherToken = process.env.SCREEN_BASELINE_PUBLISHER_TOKEN
const viewerToken = process.env.SCREEN_BASELINE_VIEWER_TOKEN
const sdkVersion = JSON.parse(readFileSync(new URL('../../node_modules/livekit-client/package.json', import.meta.url), 'utf8')).version as string

test('test page requires isolation confirmation and rejects remote plaintext', async ({ page }) => {
  await page.goto('/tests/screen_profile/baseline.html')
  await page.locator('#url').fill('ws://livekit.example')
  await page.locator('#connect').click()
  await expect(page.locator('#status')).toHaveText('isolated-test-confirmation-required')
  await page.locator('#isolated-target').check()
  await page.locator('#connect').click()
  await expect(page.locator('#status')).toHaveText('use-wss-or-loopback-test-endpoint')
})

function assertIsolatedTarget() {
  if (!isSafeLiveKitUrl(livekitUrl!)) {
    throw new Error('The baseline accepts only WSS endpoints or a local development SFU.')
  }
}

test('minimal publisher/viewer produces numeric baseline evidence', async ({ browser }, testInfo) => {
  test.setTimeout(360000)
  test.skip(!livekitUrl || !publisherToken || !viewerToken, 'Isolated short-lived publisher/viewer tokens are required.')
  test.skip(process.env.SCREEN_BASELINE_TARGET !== 'isolated-test', 'Confirm the endpoint is a dedicated non-production SFU with SCREEN_BASELINE_TARGET=isolated-test.')
  assertIsolatedTarget()
  const publisherContext = await browser.newContext()
  const viewerContext = await browser.newContext()
  const publisher = await publisherContext.newPage()
  const viewer = await viewerContext.newPage()

  try {
    await Promise.all([publisher.goto('/tests/screen_profile/baseline.html'), viewer.goto('/tests/screen_profile/baseline.html')])
    await Promise.all([
      publisher.evaluate((auth) => (window as any).screenBaseline.configure(auth), { url: livekitUrl!, token: publisherToken!, role: 'publisher' }),
      viewer.evaluate((auth) => (window as any).screenBaseline.configure(auth), { url: livekitUrl!, token: viewerToken!, role: 'viewer', numberedSynthetic: true }),
    ])
    await Promise.all([publisher.evaluate(() => (window as any).screenBaseline.connect()), viewer.evaluate(() => (window as any).screenBaseline.connect())])
    await publisher.evaluate((fps) => (window as any).screenBaseline.startSynthetic(fps), baselinePlan.frameRate)
    const firstFrameLatencyMs = await viewer.evaluate(() => (window as any).screenBaseline.waitForFirstFrame(60000))
    await viewer.waitForTimeout(measurementPlan.warmupMs)
    const [publisherSamples, viewerSamples] = await Promise.all([
      publisher.evaluate(plan => (window as any).screenBaseline.collectSamples(plan.sampleMs, plan.windowMs), measurementPlan),
      viewer.evaluate(plan => (window as any).screenBaseline.collectSamples(plan.sampleMs, plan.windowMs), measurementPlan),
    ])
    const publisherStart = publisherSamples[0], publisherEnd = publisherSamples.at(-1)
    const viewerStart = viewerSamples[0], viewerEnd = viewerSamples.at(-1)
    const elapsedSeconds = (publisherEnd.monotonicMs - publisherStart.monotonicMs) / 1000
    const sampleStart = viewerStart.monotonicMs, sampleEnd = viewerEnd.monotonicMs
    const presentationTimes = viewerSamples.slice(1).flatMap((sample: any) => sample.presentationTimestamps)
    const report = {
      schemaVersion: 1, sourceRevision: process.env.SCREEN_BASELINE_SOURCE_SHA ?? 'unknown',
      workingTreeState: process.env.SCREEN_BASELINE_WORKTREE_STATE ?? 'unknown',
      sfuImageDigest: process.env.SCREEN_BASELINE_SFU_IMAGE_DIGEST ?? 'unavailable', sdkVersion,
      deviceConfiguration: process.env.SCREEN_BASELINE_DEVICE_PROFILE ?? 'unavailable',
      browser: viewerEnd.userAgent, pageVisibility: { publisher: publisherEnd.visibilityState, viewer: viewerEnd.visibilityState },
      source: 'synthetic-moving-canvas', baselineProfileId: baselinePlan.profileId, firstFrameLatencyMs, sampleWindowSeconds: elapsedSeconds,
      warmupSeconds: measurementPlan.warmupMs / 1000, windowSeconds: measurementPlan.windowMs / 1000,
      plannedRepeats: measurementPlan.repeats,
      repeatIndex: `${process.env.SCREEN_BASELINE_REPEAT_INDEX ?? 'baseline'}-${testInfo.repeatEachIndex + 1}`,
      captureSettings: publisherEnd.captureSettings,
      captureSettingsProvenance: 'MediaStreamTrack.getSettings; not capture-throughput evidence',
      syntheticSourceFramesDelta: publisherEnd.generatedFrames - publisherStart.generatedFrames,
      syntheticGenerationFps: elapsedSeconds > 0 ? (publisherEnd.generatedFrames - publisherStart.generatedFrames) / elapsedSeconds : null,
      requestedSyntheticCaptureFps: publisherEnd.requestedSyntheticFps,
      encodedP05Fps: encodedP05Fps(publisherSamples),
      decodedP05Fps: decodedP05Fps(viewerSamples),
      inboundAndOutboundTrackStats: { publisher: publisherSamples, viewer: viewerSamples },
      statsProvenance: 'LiveKit Track.getRTCStatsReport; whitelisted RTP counters and selected candidate protocol; missing fields are null',
      presentation: presentationMetrics(presentationTimes, sampleStart, sampleEnd),
      syntheticFrameSequence: frameSequenceMetrics(viewerSamples.slice(1).flatMap((sample: any) => sample.presentedFrameIds)),
      presentationProvenance: 'HTMLVideoElement.requestVideoFrameCallback plus numbered synthetic pixel marker; neither proves monitor scanout',
      sourceSwitchLatencyMs: null,
      thresholdClaims: false,
    }
    await testInfo.attach('screen-share-baseline-numeric.json', { body: JSON.stringify(report, null, 2), contentType: 'application/json' })
    expect(firstFrameLatencyMs).toBeGreaterThanOrEqual(0)
    expect(publisherEnd.outbound.layers.some((layer: any) => layer.framesEncoded > (publisherStart.outbound.layers.find((start: any) => start.rid === layer.rid)?.framesEncoded ?? 0))).toBe(true)
    expect(report.presentation.frameCallbacks).toBeGreaterThan(0)
    expect(report.syntheticFrameSequence.markerFrames).toBeGreaterThan(0)
  } finally {
    await Promise.all([publisher.evaluate(() => (window as any).screenBaseline.stop()).catch(() => undefined), viewer.evaluate(() => (window as any).screenBaseline.stop()).catch(() => undefined)])
    await Promise.all([publisherContext.close(), viewerContext.close()])
  }
})
