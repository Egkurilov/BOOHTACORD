import { expect, test } from '@playwright/test'

for (const { mode, sampleRate, fallbackReason } of [
  { mode: 'browser' },
  { mode: 'off' },
  { mode: 'rnnoise', sampleRate: 48000, fallbackReason: 'asset-load' },
  { mode: 'rnnoise', sampleRate: 44100, fallbackReason: 'sample-rate' },
] as const) {
  for (const interruptPublication of [false, true]) {
    const scenario = interruptPublication ? 'survives signalling restart' : 'publishes on first join'
    const processing = mode === 'rnnoise' ? `rnnoise ${fallbackReason} fallback` : mode
    test(`production microphone join ${scenario} (${processing})`, async ({ browser }) => {
      const senderContext = await browser.newContext({ permissions: ['microphone'] }), receiverContext = await browser.newContext()
      const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
      try {
        if (mode === 'rnnoise') await sender.addInitScript((sampleRate) => {
          const NativeAudioContext = window.AudioContext
          // Pin only this synthetic sender's context. Host defaults differ
          // across macOS and Linux; each test must reach its intended fallback.
          window.AudioContext = class extends NativeAudioContext {
            constructor(options?: AudioContextOptions) { super({ ...options, sampleRate }) }
          }
        }, sampleRate)
        for (const page of [sender, receiver]) {
          await page.goto('/tests/audio/fixture.html')
          await page.waitForFunction(() => 'microphoneJoinGate' in window && 'livekitAudioGate' in window)
        }
        if (mode === 'rnnoise') await sender.route('**/audio/rnnoise/**', (route) => route.fulfill({ status: 404, contentType: 'text/plain', body: 'Unavailable test asset' }))
        await receiver.evaluate(() => (window as any).livekitAudioGate.receiver())
        const result = await sender.evaluate(({ mode, interruptPublication }) => (window as any).microphoneJoinGate.join(mode, interruptPublication), { mode, interruptPublication })
        expect(result).toMatchObject({ microphone: 'PUBLISHED', attempts: interruptPublication ? 2 : 1, cancellations: interruptPublication ? 1 : 0, reconnects: interruptPublication ? 1 : 0, publications: 1, enabledAtPublish: interruptPublication ? [false, false] : [false] })
        if (mode === 'rnnoise') expect(result.processingState).toMatchObject({ requestedMode: 'rnnoise', status: 'fallback', fallbackReason })
        await expect.poll(async () => {
          const sample = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
          return sample.readings.some((reading: any) => reading.rms > 0.001 && reading.nonfinite === 0)
        }, { timeout: 15000 }).toBe(true)
        await sender.evaluate(() => (window as any).microphoneJoinGate.mute())
        await receiver.waitForTimeout(400)
        await receiver.evaluate(() => (window as any).livekitAudioGate.read())
        await receiver.waitForTimeout(400)
        const muted = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
        expect(muted.readings.length).toBeGreaterThan(0)
        expect(muted.readings.every((reading: any) => reading.peak < 0.0001)).toBe(true)
        expect(await sender.evaluate(() => (window as any).microphoneJoinGate.stop())).toEqual({ ended: true })
      } finally {
        await sender.evaluate(() => (window as any).microphoneJoinGate?.stop()).catch(() => {})
        await receiver.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
        await senderContext.close(); await receiverContext.close()
      }
    })
  }
}
