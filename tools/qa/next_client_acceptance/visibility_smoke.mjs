import { expect } from './fixture.mjs'
import { whileWindowHidden } from './window_visibility.mjs'
import { nativeBrowser } from './native_browser.mjs'

const owned = await nativeBrowser()
try {
  const page = owned.page
  await page.goto('data:text/html,<title>Disposable visibility witness</title>')
  await expect.poll(() => page.evaluate(() => document.visibilityState)).toBe('visible')
  let observed = false
  await whileWindowHidden(page, async () => {
    observed = await page.evaluate(() => document.visibilityState === 'hidden')
  })
  expect(observed).toBe(true)
  await expect.poll(() => page.evaluate(() => document.visibilityState)).toBe('visible')
  console.log('Native headed window hidden/visible witness PASS')
} finally { await owned.close() }
