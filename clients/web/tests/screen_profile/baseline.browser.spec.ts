import { readFileSync } from 'node:fs'
import { expect, test } from '@playwright/test'

const livekitUrl = process.env.SCREEN_BASELINE_LIVEKIT_URL
const publisherToken = process.env.SCREEN_BASELINE_PUBLISHER_TOKEN
const viewerToken = process.env.SCREEN_BASELINE_VIEWER_TOKEN
const sdkVersion = JSON.parse(readFileSync(new URL('../../node_modules/livekit-client/package.json', import.meta.url), 'utf8')).version as string

test.describe('isolated LiveKit baseline', () => {
test.skip(!livekitUrl || !publisherToken || !viewerToken, 'Isolated short-lived publisher/viewer tokens are required.')

test('minimal publisher/viewer produces numeric baseline evidence', async ({ browser }, testInfo) => {
  test.setTimeout(90000)
  const publisherContext = await browser.newContext()
  const viewerContext = await browser.newContext()
  const publisher = await publisherContext.newPage()
  const viewer = await viewerContext.newPage()

  try {
    await Promise.all([publisher.goto('/tests/screen_profile/baseline.html'), viewer.goto('/tests/screen_profile/baseline.html')])
    await Promise.all([
      publisher.evaluate((auth) => (window as any).screenBaseline.configure(auth), { url: livekitUrl!, token: publisherToken!, role: 'publisher' }),
      viewer.evaluate((auth) => (window as any).screenBaseline.configure(auth), { url: livekitUrl!, token: viewerToken!, role: 'viewer' }),
    ])
    await Promise.all([
      publisher.evaluate(() => (window as any).screenBaseline.connect()),
      viewer.evaluate(() => (window as any).screenBaseline.connect()),
    ])
    await publisher.evaluate(() => (window as any).screenBaseline.startSynthetic())
    const firstFrameLatencyMs = await viewer.evaluate(() => (window as any).screenBaseline.waitForFirstFrame(30000))
    await viewer.waitForTimeout(5000)
    const [publisherSamples, viewerSamples] = await Promise.all([
      publisher.evaluate(() => (window as any).screenBaseline.collectSamples(10000, 1000)),
      viewer.evaluate(() => (window as any).screenBaseline.collectSamples(10000, 1000)),
    ])
    const publisherStart = publisherSamples[0], publisherEnd = publisherSamples.at(-1)
    const viewerStart = viewerSamples[0], viewerEnd = viewerSamples.at(-1)
    const elapsedSeconds = (publisherEnd.monotonicMs - publisherStart.monotonicMs) / 1000
    const rates: number[] = []
    for (let index = 1; index < publisherSamples.length; index++) {
      const start = publisherSamples[index - 1], end = publisherSamples[index]
      if (start.visibilityState !== 'visible' || end.visibilityState !== 'visible') continue
      const starts = new Map(start.outbound.map((row: any) => [row.rid, row]))
      for (const layer of end.outbound) {
        const previous: any = starts.get(layer.rid)
        if (previous?.framesEncoded != null && layer.framesEncoded != null) {
          const seconds = (end.monotonicMs - start.monotonicMs) / 1000
          if (seconds > 0) rates.push((layer.framesEncoded - previous.framesEncoded) / seconds)
        }
      }
    }
    const orderedRates = [...rates].sort((a, b) => a - b)
    const p05EncodedFps = orderedRates.length ? orderedRates[Math.ceil(orderedRates.length * 0.05) - 1] : null
    const sampleStart = viewerStart.monotonicMs, sampleEnd = viewerEnd.monotonicMs
    const presentationTimes = viewerEnd.presentationTimestamps.filter((time: number) => time >= sampleStart && time <= sampleEnd)
    const presentationGapsMs = presentationTimes.slice(1).map((time: number, index: number) => time - presentationTimes[index])
    const sourceFrameDelta = publisherEnd.generatedFrames - publisherStart.generatedFrames
    const report = {
      schemaVersion: 1,
      sourceRevision: process.env.SCREEN_BASELINE_SOURCE_SHA ?? 'unknown',
      workingTreeState: process.env.SCREEN_BASELINE_WORKTREE_STATE ?? 'unknown',
      sfuImageDigest: process.env.SCREEN_BASELINE_SFU_IMAGE_DIGEST ?? 'unavailable',
      sdkVersion,
      browser: viewerEnd.userAgent,
      pageVisibility: { publisher: publisherEnd.visibilityState, viewer: viewerEnd.visibilityState },
      source: 'synthetic-moving-canvas',
      firstFrameLatencyMs,
      sampleWindowSeconds: elapsedSeconds,
      warmupSeconds: 5,
      windowSeconds: 1,
      repeatIndex: process.env.SCREEN_BASELINE_REPEAT_INDEX ?? 'unspecified',
      captureSettings: publisherEnd.captureSettings,
      captureSettingsProvenance: 'MediaStreamTrack.getSettings; not capture-throughput evidence',
      syntheticSourceFramesDelta: sourceFrameDelta,
      syntheticSourceFps: sourceFrameDelta / elapsedSeconds,
      encodedP05Fps: p05EncodedFps,
      presentedFrameCallbacksDelta: viewerEnd.presentedFrameCallbacks - viewerStart.presentedFrameCallbacks,
      presentationGapCountOver500Ms: presentationGapsMs.filter((gap: number) => gap > 500).length,
      maxPresentationCallbackGapMs: presentationGapsMs.length ? Math.max(...presentationGapsMs) : null,
      playbackQualityStart: viewerStart.playbackQuality,
      playbackQualityEnd: viewerEnd.playbackQuality,
      rawSenderSamples: publisherSamples,
      rawViewerSamples: viewerSamples.map(({ presentationTimestamps: _timestamps, ...sample }: any) => sample),
      presentationTimestampsMonotonicMs: presentationTimes,
      presentationProvenance: 'HTMLVideoElement.requestVideoFrameCallback; not unique-frame or display-scanout proof',
      thresholdClaims: false,
    }
    await testInfo.attach('screen-share-baseline-numeric.json', {
      body: JSON.stringify(report, null, 2),
      contentType: 'application/json',
    })
    expect(firstFrameLatencyMs).toBeGreaterThanOrEqual(0)
    expect(publisherEnd.outbound.some((layer: any) => layer.framesEncoded > publisherStart.outbound.find((start: any) => start.rid === layer.rid)?.framesEncoded)).toBe(true)
    expect(report.presentedFrameCallbacksDelta).toBeGreaterThan(0)
  } finally {
    await Promise.all([
      publisher.evaluate(() => (window as any).screenBaseline.stop()).catch(() => undefined),
      viewer.evaluate(() => (window as any).screenBaseline.stop()).catch(() => undefined),
    ])
    await Promise.all([publisherContext.close(), viewerContext.close()])
  }
})
})
