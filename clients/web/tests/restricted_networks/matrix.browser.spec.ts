import { expect, test } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
test('measures isolated transport restriction using real LiveKit RTP', async ({ browser }) => {
  const profile = process.env.NETWORK_PROFILE
  expect(['baseline', 'udp-blocked', 'signal-only', 'signal-blocked', 'recovery']).toContain(profile)
  const contexts = [await browser.newContext(), await browser.newContext()]
  const pages = [await contexts[0]!.newPage(), await contexts[1]!.newPage()]
  const [sender, receiver] = pages
  try {
    for (const page of pages) { await page.goto('/tests/restricted_networks/fixture.html'); await page.waitForFunction(() => 'restrictedNetwork' in window) }
    const connected = await receiver!.evaluate(() => (window as any).restrictedNetwork.connect('receiver'))
    const expected = profile !== 'signal-only' && profile !== 'signal-blocked'
    expect(connected).toBe(expected)
    let sent: any = null, received: any
    if (expected) {
      expect(await sender!.evaluate(() => (window as any).restrictedNetwork.connect('sender'))).toBe(true)
      await sender!.evaluate(() => (window as any).restrictedNetwork.publish())
      await expect.poll(async () => {
        received = await receiver!.evaluate(() => (window as any).restrictedNetwork.read())
        return received.firstRtpObservedMs
      }, { timeout: 15000, intervals: [500] }).not.toBeNull()
      sent = await sender!.evaluate(() => (window as any).restrictedNetwork.read())
      const requiredProtocol = profile === 'udp-blocked' ? 'tcp' : 'udp'
      for (const report of [sent, received]) {
        expect(report.signalMs).not.toBeNull(); expect(report.sdkJoinMs).not.toBeNull()
        expect(report.iceObservedMs).not.toBeNull()
        expect(report.transports.some((transport: any) => transport.selected && transport.protocol === requiredProtocol)).toBe(true)
      }
      expect(received.transports.some((transport: any) => transport.audioBytesReceived > 0)).toBe(true)
      expect(sent.transports.some((transport: any) => transport.audioBytesSent > 0)).toBe(true)
    } else {
      received = await receiver!.evaluate(() => (window as any).restrictedNetwork.read())
      expect(received.outcome).toBe('failed'); expect(received.sdkJoinMs).toBeNull()
      expect(received.iceObservedMs).toBeNull(); expect(received.firstRtpObservedMs).toBeNull()
      if (profile === 'signal-only') expect(received.signalMs).not.toBeNull()
      else expect(received.signalMs).toBeNull()
    }
    const result = { profile, browser: browser.version(), connectivity: connected ? 'PASS' : 'FAIL',
      measurementGate: 'PASS', sender: sent, receiver: received, audibleQuality: 'NOT_RUN' }
    expect(JSON.stringify(result)).not.toMatch(/candidateId|address|token|sdp|identity/)
    await writeFile(process.env.NETWORK_REPORT_PATH!, JSON.stringify(result, null, 2) + '\n')
    console.log(JSON.stringify({ profile, measurementGate: result.measurementGate, connectivity: result.connectivity }))
  } finally {
    for (const page of pages) await page.evaluate(() => (window as any).restrictedNetwork?.stop()).catch(() => {})
    for (const context of contexts) await context.close()
  }
})
