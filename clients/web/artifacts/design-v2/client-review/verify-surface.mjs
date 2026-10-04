import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

export function verifySurfaceGeometry(surface, path) {
  const reference = JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, ''))
  for (const key of Object.keys(surface)) {
    for (let i = 0; i < 4; i++) assert.ok(Math.abs(surface[key].box[i] - reference[key].box[i]) < .05,
      `${key} box[${i}]: ${surface[key].box[i]} != ${reference[key].box[i]}`)
  }
}

export async function observeObjectUrlRelease(page) {
  await page.addInitScript(() => {
    const revoke = URL.revokeObjectURL.bind(URL)
    window.__qaRevokedImages = []
    URL.revokeObjectURL = value => { window.__qaRevokedImages.push(value); revoke(value) }
  })
}

export async function verifyImageActions(page) {
  const dialog = page.locator('.attachment-image-dialog[open]')
  const opener = page.getByRole('button', { name: 'Открыть изображение evening-session.png' })
  const link = dialog.getByRole('link', { name: 'Скачать' })
  const url = await link.getAttribute('href')
  const [download] = await Promise.all([page.waitForEvent('download'), link.click()])
  assert.equal(download.suggestedFilename(), 'evening-session.png')
  await download.delete()
  if (page.viewportSize().width <= 1023) {
    for (const selector of ['.attachment-image-dialog__download', '.attachment-image-dialog__close']) {
      const box = await dialog.locator(selector).boundingBox()
      assert.ok(box.width >= 44 && box.height >= 44)
    }
  }
  assert.equal(await dialog.locator('header').evaluate(el => el.scrollWidth <= el.clientWidth), true)
  await page.keyboard.press('Escape')
  await dialog.waitFor({ state: 'hidden' })
  await page.waitForFunction(url => window.__qaRevokedImages.includes(url), url)
  assert.equal(await opener.evaluate(el => el === document.activeElement), true)
  await opener.click()
  await page.locator('.attachment-image-dialog__image').waitFor({ state: 'visible' })
  assert.notEqual(await page.locator('.attachment-image-dialog__image').getAttribute('src'), url)
}
