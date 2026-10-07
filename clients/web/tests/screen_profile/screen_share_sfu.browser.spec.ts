import { randomUUID } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { AccessToken } from 'livekit-server-sdk'
import { expect, test } from '@playwright/test'
import type { SmokeSnapshot } from './screen_share_sfu/types'

const livekitUrl = process.env.SCREEN_SHARE_SFU_URL ?? 'ws://127.0.0.1:17880'
const image = process.env.SCREEN_SHARE_SFU_IMAGE ?? 'unknown-outside-native-gate'
const sdkVersion = JSON.parse(readFileSync(new URL('../../node_modules/livekit-client/package.json', import.meta.url), 'utf8')).version as string
const evidenceSchema = JSON.parse(readFileSync(new URL('../../../../contracts/screen-share-sfu-smoke-evidence-v1.schema.json', import.meta.url), 'utf8'))

async function token(room: string, role: 'publisher' | 'viewer') {
  const value = new AccessToken('devkey', 'secret', { identity: `${role}-${randomUUID()}`, ttl: '2m' })
  value.addGrant({ roomJoin: true, room, canPublish: role === 'publisher', canSubscribe: role === 'viewer' })
  return value.toJwt()
}

function assertLoopbackTarget(value: string) {
  const target = new URL(value)
  if (target.protocol !== 'ws:' || !['localhost', '127.0.0.1', '::1', '[::1]'].includes(target.hostname)) {
    throw new Error('screen-share smoke accepts only a local loopback SFU')
  }
}

test('real LiveKit SDK discovers without subscribing, selects, presents, and cleans up', async ({ browser }, testInfo) => {
  test.setTimeout(90000)
  const room = `screen-smoke-${randomUUID()}`
  const publisherContext = await browser.newContext(), viewerContext = await browser.newContext()
  const publisher = await publisherContext.newPage(), viewer = await viewerContext.newPage()
  const auth = await Promise.all([token(room, 'publisher'), token(room, 'viewer')])
  let stage = 'connect', status = 'FAIL', failureType: string | null = null
  let beforeSelect: SmokeSnapshot | null = null, selected: SmokeSnapshot | null = null
  let publisherStats: SmokeSnapshot | null = null
  try {
    assertLoopbackTarget(livekitUrl)
    await Promise.all([publisher.goto('/tests/screen_profile/screen_share_sfu.html'), viewer.goto('/tests/screen_profile/screen_share_sfu.html')])
    await Promise.all([
      publisher.evaluate(({ url, auth }) => window.screenShareSfuSmoke.open(url, auth, 'publisher'), { url: livekitUrl, auth: auth[0] }),
      viewer.evaluate(({ url, auth }) => window.screenShareSfuSmoke.open(url, auth, 'viewer'), { url: livekitUrl, auth: auth[1] }),
    ])
    stage = 'publish'
    await publisher.evaluate(() => window.screenShareSfuSmoke.publishSynthetic())
    stage = 'discover-without-subscribe'
    await expect.poll(async () => (await viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())).publicationDiscovered).toBe(true)
    await viewer.waitForTimeout(300)
    beforeSelect = await viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())
    expect(beforeSelect).toMatchObject({ subscriptionActive: false, activeVideoTracks: 0, presentedFrameCallbacks: 0 })

    stage = 'select-and-present'
    await viewer.evaluate(() => window.screenShareSfuSmoke.select())
    await expect.poll(() => viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())).toMatchObject({ subscriptionActive: true, activeVideoTracks: 1 })
    await expect.poll(async () => (await viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())).presentedFrameCallbacks).toBeGreaterThan(0)
    await expect.poll(async () => (await publisher.evaluate(() => window.screenShareSfuSmoke.snapshot())).outboundFramesEncoded).toBeGreaterThan(0)
    await expect.poll(async () => (await viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())).inboundFramesDecoded).toBeGreaterThan(0)
    await viewer.evaluate(() => window.screenShareSfuSmoke.select())
    selected = await viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())
    publisherStats = await publisher.evaluate(() => window.screenShareSfuSmoke.snapshot())
    expect(selected.videoWidth).toBeGreaterThan(0)
    expect(selected.videoHeight).toBeGreaterThan(0)

    stage = 'unselect'
    await viewer.evaluate(() => window.screenShareSfuSmoke.unselect())
    await expect.poll(() => viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())).toMatchObject({ subscriptionActive: false, activeVideoTracks: 0 })
    stage = 'unpublish'
    await publisher.evaluate(() => window.screenShareSfuSmoke.stop())
    await expect.poll(async () => (await viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())).publisherRemoved).toBe(true)
    await viewer.evaluate(() => window.screenShareSfuSmoke.stop())
    expect(await viewer.evaluate(() => window.screenShareSfuSmoke.snapshot())).toMatchObject({
      publicationDiscovered: false, activeVideoTracks: 0, subscriptionActive: false,
    })
    status = 'PASS'
    stage = 'complete'
  } catch (error) {
    failureType = error instanceof Error ? error.name : 'UnknownError'
    throw error
  } finally {
    await Promise.all([
      publisher.evaluate(() => window.screenShareSfuSmoke?.stop()).catch(() => undefined),
      viewer.evaluate(() => window.screenShareSfuSmoke?.stop()).catch(() => undefined),
    ])
    const source = publisherStats?.sourceCapture
    const evidence = {
      schemaVersion: 1,
      sourceRevision: process.env.GITHUB_SHA ?? 'local',
      versions: { livekitServerImage: image, livekitClient: sdkVersion, browser: browser.version() },
      environment: { runnerOS: process.platform, hosted: process.env.GITHUB_ACTIONS === 'true', mode: 'headless-chromium' },
      source: { mode: 'synthetic-canvas', width: source?.width ?? null, height: source?.height ?? null, requestedFps: 15 },
      counts: {
        publicationDiscovered: beforeSelect ? 1 : 0,
        framesBeforeSelection: beforeSelect?.presentedFrameCallbacks ?? null,
        syntheticSourceFrames: publisherStats?.syntheticFramesProduced ?? null,
        encoded: publisherStats?.outboundFramesEncoded ?? null,
        decoded: selected?.inboundFramesDecoded ?? null,
        presented: selected?.presentedFrameCallbacks ?? null,
      },
      measurements: { firstFrameLatencyMs: selected?.firstFrameLatencyMs ?? null },
      quantiles: { firstFrameLatencyP50Ms: null, firstFrameLatencyP95Ms: null },
      results: { headlessCorrectness: status, hardwarePerformance: 'NOT_RUN', failedAt: status === 'FAIL' ? stage : null, failureType },
      scenario: ['publish synthetic screen', 'discover while unsubscribed', 'select and present', 'unselect', 'unpublish', 'teardown'],
      limitations: ['shared headless runner; one 640x360 synthetic source at 15fps; no physical FPS or latency claim'],
    }
    expect(Object.keys(evidence).sort()).toEqual([...evidenceSchema.required].sort())
    expect(evidenceSchema.properties.results.properties.hardwarePerformance.enum).toContain('NOT_RUN')
    expect(JSON.stringify(evidence)).not.toMatch(/token|identity|sdp|credential|candidate/i)
    await testInfo.attach('screen-share-sfu-smoke.json', { body: JSON.stringify(evidence, null, 2), contentType: 'application/json' })
    await Promise.all([publisherContext.close(), viewerContext.close()])
  }
})
