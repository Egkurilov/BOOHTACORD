import { expect, test } from '@playwright/test'

test('a channel URL restores the accessible selected channel after load and refresh', async ({ page }) => {
  await page.goto('/tests/workspace_location/fixture.html#workspace/channel/channel-2')
  await expect(page.locator('#selected-channel')).toHaveText('channel-2')
  await expect(page).toHaveURL(/#workspace\/channel\/channel-2$/)

  await page.reload()

  await expect(page.locator('#selected-channel')).toHaveText('channel-2')
  await expect(page).toHaveURL(/#workspace\/channel\/channel-2$/)
})

test('an inaccessible channel URL falls back to the authorized topology', async ({ page }) => {
  await page.goto('/tests/workspace_location/fixture.html#workspace/channel/hidden-channel')

  await expect(page.locator('#selected-channel')).toHaveText('channel-1')
  await expect(page).toHaveURL(/\/tests\/workspace_location\/fixture\.html$/)
})

test('channel navigation participates in browser Back and Forward', async ({ page }) => {
  await page.goto('/tests/workspace_location/fixture.html')
  await expect(page).toHaveURL(/#workspace\/channel\/channel-1$/)
  await page.locator('#select-channel-2').click()
  await expect(page.locator('#selected-channel')).toHaveText('channel-2')
  await expect(page).toHaveURL(/#workspace\/channel\/channel-2$/)

  await page.goBack()
  await expect(page.locator('#selected-channel')).toHaveText('channel-1')
  await page.goForward()
  await expect(page.locator('#selected-channel')).toHaveText('channel-2')
})

test('channel selection from the navigation drawer leaves no stale drawer entry', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/workspace_location/fixture.html')
  await page.locator('#open-nav').click()
  await expect(page.locator('#nav-state')).toHaveText('open')
  await page.locator('#select-channel-2').click()
  await expect(page.locator('#nav-state')).toHaveText('closed')

  await page.goBack()
  await expect(page.locator('#selected-channel')).toHaveText('channel-1')
  await expect(page.locator('#nav-state')).toHaveText('closed')
})
