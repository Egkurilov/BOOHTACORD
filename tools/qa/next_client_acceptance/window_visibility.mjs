import { expect } from './fixture.mjs'

export async function whileWindowHidden(page, action) {
  const session = await page.context().newCDPSession(page)
  const { windowId } = await session.send('Browser.getWindowForTarget')
  try {
    await session.send('Browser.setWindowBounds', { windowId, bounds: { windowState: 'minimized' } })
    await expect.poll(() => page.evaluate(() => document.visibilityState)).toBe('hidden')
    await action()
  } finally {
    await session.send('Browser.setWindowBounds', { windowId, bounds: { windowState: 'normal' } })
    await page.bringToFront()
    await expect.poll(() => page.evaluate(() => document.visibilityState)).toBe('visible')
    await session.detach()
  }
}
