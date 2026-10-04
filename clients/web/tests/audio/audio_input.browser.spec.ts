import { expect, test, type Page } from '@playwright/test'

async function choose(page: Page, id: string) {
  const selector = page.getByRole('combobox', { name: 'Микрофон', exact: true })
  await selector.selectOption(id)
  await expect(selector).toHaveValue(id)
  await expect(selector).toBeEnabled()
}
async function hear(page: Page, frequency: number) {
  await expect.poll(async () => {
    const sample = await page.evaluate(() => (window as any).audioInputGate.sample())
    return sample.rms > 0.01 && sample.nonfinite === 0 && Math.abs(sample.frequency - frequency) < 30
  }, { timeout: 15000 }).toBe(true)
}
async function silence(page: Page) {
  await expect.poll(async () => (await page.evaluate(() => (window as any).audioInputGate.sample())).rms, { timeout: 15000 }).toBeLessThan(0.001)
}

for (const mode of ['off', 'browser', 'rnnoise'] as const) {
  test(`selected input reaches a real peer without a probe and survives mute/reconnect (${mode})`, async ({ browser }) => {
    const senderContext = await browser.newContext(), receiverContext = await browser.newContext()
    const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
    try {
      await sender.route('**/api/v1/auth/session', route => route.fulfill({ json: { account_id: 'qa-account', role: 'MEMBER' } }))
      if (mode === 'rnnoise') await sender.route('**/audio/rnnoise/**', route => route.fulfill({ status: 404, body: 'Synthetic asset fallback' }))
      await sender.goto('/tests/audio/fixture.html'); await receiver.goto('/tests/audio/fixture.html')
      await sender.evaluate(mode => (window as any).audioInputGate.mount(mode), mode)
      await choose(sender, 'mic-2')
      expect((await sender.evaluate(() => (window as any).audioInputGate.read())).captures).toEqual([])
      await receiver.evaluate(() => (window as any).audioInputGate.receiver())
      const joined = await sender.evaluate(() => (window as any).audioInputGate.join())
      expect(joined.captures[0].deviceId).toBe('mic-2')
      expect(joined.ownedCapture).toBe(true)
      await hear(receiver, 880)
      await choose(sender, 'mic-1'); await hear(receiver, 440)
      await sender.getByRole('button', { name: 'Проверить микрофон', exact: true }).click()
      await expect(sender.getByRole('button', { name: 'Остановить проверку микрофона' })).toBeVisible()
      const before = await sender.evaluate(() => (window as any).audioInputGate.read())
      await sender.getByRole('button', { name: 'Остановить проверку микрофона' }).click()
      expect((await sender.evaluate(() => (window as any).audioInputGate.read())).captures).toEqual(before.captures)
      await sender.evaluate(() => (window as any).audioInputGate.mute())
      await silence(receiver)
      await choose(sender, 'mic-2'); await silence(receiver)
      expect((await sender.evaluate(() => (window as any).audioInputGate.read())).enabled).toBe(false)
      await sender.evaluate(() => (window as any).audioInputGate.reconnect())
      await expect.poll(async () => (await sender.evaluate(() => (window as any).audioInputGate.read())).captures.length).toBeGreaterThan(before.captures.length + 1)
      await silence(receiver)
      expect((await sender.evaluate(() => (window as any).audioInputGate.read())).selected).toBe('mic-2')
      await sender.evaluate(() => (window as any).audioInputGate.mute(false)); await hear(receiver, 880)
      await sender.evaluate(() => (window as any).audioInputGate.deafen(true))
      await choose(sender, 'mic-1'); await silence(receiver)
      await sender.evaluate(() => (window as any).audioInputGate.deafen(false)); await hear(receiver, 440)
      await sender.evaluate(() => (window as any).audioInputGate.unplug('mic-1'))
      await expect(sender.getByText(/Используется системный микрофон|Сохранён предыдущий источник|Микрофон недоступен/)).toBeVisible()
      await hear(receiver, 880)
      await sender.evaluate(() => (window as any).audioInputGate.removeAll())
      await expect(sender.getByRole('status').filter({ hasText: /Микрофон недоступен. Отправка звука выключена/ })).toBeVisible()
      await silence(receiver)
    } finally {
      await sender.evaluate(() => (window as any).audioInputGate?.stop()).catch(() => {})
      await receiver.evaluate(() => (window as any).audioInputGate?.stop()).catch(() => {})
      await senderContext.close(); await receiverContext.close()
    }
  })
}

test('prejoin probe and reload do not select a different call source; listener selection never captures', async ({ page }) => {
  await page.route('**/api/v1/auth/session', route => route.fulfill({ json: { account_id: 'qa-account', role: 'MEMBER' } }))
  await page.goto('/tests/audio/fixture.html')
  await page.evaluate(() => (window as any).audioInputGate.mount())
  await choose(page, 'mic-2')
  await page.getByRole('button', { name: 'Проверить микрофон', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Остановить проверку микрофона' })).toBeVisible()
  await page.getByRole('button', { name: 'Остановить проверку микрофона' }).click()
  const before = await page.evaluate(() => (window as any).audioInputGate.read())
  expect(before.selected).toBe('mic-2')
  expect(before.captures[0]).toEqual({ deviceId: 'mic-2', ended: true })
  await page.evaluate(() => (window as any).audioInputGate.stop())
  await page.reload()
  await page.evaluate(() => (window as any).audioInputGate.mount())
  await expect(page.getByRole('combobox', { name: 'Микрофон', exact: true })).toHaveValue('mic-2')
  await page.evaluate(() => (window as any).audioInputGate.join('listener'))
  await choose(page, 'mic-1')
  expect((await page.evaluate(() => (window as any).audioInputGate.read())).captures).toEqual([])
  await page.evaluate(() => (window as any).audioInputGate.mute(false))
  expect((await page.evaluate(() => (window as any).audioInputGate.read())).captures[0].deviceId).toBe('mic-1')
  await page.evaluate(() => (window as any).audioInputGate.stop())
})
