import { expect, test, type Browser } from '@playwright/test'
import { voiceAudioProfiles } from '../../../src/voice/audio_profile/generated'
import type { VoiceAudioProfile } from '../../../src/voice/audio_profile/profile'
async function measure(browser: Browser, profile: VoiceAudioProfile, red?: boolean) {
    const contexts = [await browser.newContext(), await browser.newContext()]
    const sender = await contexts[0]!.newPage(), receiver = await contexts[1]!.newPage()
    try {
      for (const page of [sender, receiver]) {
        await page.goto('/tests/audio/fixture.html')
        expect(await page.evaluate(() => typeof (window as any).voiceParity)).toBe('object')
      }
      await receiver.evaluate(() => (window as any).voiceParity.receiver())
      const published = await sender.evaluate(args => (window as any).voiceParity.sender(args.id, args.red), { id: profile.id, red })
      expect(published.senderCap).toBe(profile.maxBitrate)
      expect(published.contextRate).toBe(48000)
      const active = await sender.evaluate(() => (window as any).voiceParity.sample(4))
      const inbound = await receiver.evaluate(() => (window as any).voiceParity.sample(2))
      expect(active.profile).toBe(profile.id)
      expect(active.codec).toBe('opus'); expect(inbound.codec).toBe('opus')
      expect(active.clockRate).toBe(48000); expect(inbound.clockRate).toBe(48000)
      expect(active.meanBitrateBps).toBeGreaterThan(0)
      expect(inbound.meanBitrateBps).toBeGreaterThan(0)
      await sender.evaluate(() => (window as any).voiceParity.silence())
      const quiet = await sender.evaluate(() => (window as any).voiceParity.sample(4))
      expect(quiet.meanBitrateBps).toBeLessThan(active.meanBitrateBps / 2)
      const result = { gate: 'actual-LiveKit-voice-profile', profile: profile.id, requestedRed: red ?? profile.red,
        senderCap: published.senderCap, contextRate: published.contextRate,
        active, inbound, silence: quiet, acousticQuality: 'NOT_RUN', windowsDevice: 'NOT_RUN' }
      console.log(JSON.stringify(result))
      return result
    } finally {
      for (const page of [sender, receiver]) {
        if (!page.isClosed()) await page.evaluate(() => (window as any).voiceParity?.stop()).catch(() => {})
      }
      for (const context of contexts) await context.close()
    }
}
for (const profile of voiceAudioProfiles) {
  test(`${profile.id} measures actual LiveKit microphone RTP and silence`, async ({ browser }) => {
    await measure(browser, profile)
  })
}
test('isolates RED overhead without changing the production profile', async ({ browser }) => {
  const profile = voiceAudioProfiles[1]!
  const withRed = await measure(browser, profile, true)
  const withoutRed = await measure(browser, profile, false)
  const ratio = withRed.active.meanBitrateBps / withoutRed.active.meanBitrateBps
  expect(ratio).toBeGreaterThan(1.6); expect(ratio).toBeLessThan(2.5)
  expect(withoutRed.active.meanBitrateBps).toBeLessThan(profile.maxBitrate * 1.25)
  expect(withRed.active.red.every((flag: unknown) => flag !== false)).toBe(true)
  console.log(JSON.stringify({ gate: 'RED-controlled-overhead', ratio, acousticQuality: 'NOT_RUN' }))
})
