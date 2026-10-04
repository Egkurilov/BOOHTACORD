import assert from 'node:assert/strict'
import { chromium } from '@playwright/test'
const browser = await chromium.launch({ headless: true })
const results = []
try {
  for (const width of [1440, 390, 320]) {
    const page = await browser.newPage({ viewport: { width, height: width === 320 ? 640 : 900 } })
    await page.goto(`${process.env.DESIGN_V2_URL || 'http://127.0.0.1:4181'}/artifacts/design-v2/screen-quality/fixture.html`)
    const dialog = page.getByRole('dialog', { name: 'Качество трансляции' })
    await dialog.waitFor()
    for (const resolution of [720, 1080, 1440]) for (const fps of [15, 30, 60]) {
      await dialog.getByRole('radio', { name: `${resolution}p`, exact: true }).check()
      await dialog.getByRole('radio', { name: `${fps} FPS`, exact: true }).check()
      await dialog.getByRole('button', { name: 'Применить' }).click()
      assert.equal(await page.evaluate(() => window.qualityEvents.at(-1)), `P${resolution}_${fps}`)
    }
    const warning = await dialog.locator('.screen-share-quality__warning').boundingBox()
    const footer = await dialog.locator('footer').boundingBox()
    assert.ok(warning.y + warning.height <= footer.y)
    assert.ok(footer.y + footer.height <= page.viewportSize().height)
    if (width <= 1023) {
      const radio = dialog.getByRole('radio', { name: '720p', exact: true })
      const box = await radio.boundingBox()
      assert.ok(box.height >= 44)
      await page.mouse.click(box.x + box.width / 2, box.y + .5)
      assert.equal(await radio.isChecked(), true)
    }
    await dialog.getByRole('button', { name: 'Отмена' }).click()
    await page.keyboard.press('Escape')
    assert.deepEqual(await page.evaluate(() => window.qualityEvents.slice(-2)), ['cancel', 'cancel'])
    results.push({ width, profiles: 9, containment: true, cancellation: true })
    await page.close()
  }
  console.log(JSON.stringify(results, null, 2))
} finally { await browser.close() }
