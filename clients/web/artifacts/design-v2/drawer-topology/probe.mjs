import { chromium, expect } from '@playwright/test'
import { mkdir, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { installFixture } from './fixture.mjs'

const output = resolve(process.argv[2] ?? 'artifacts/design-v2/drawer-topology-output')
await mkdir(output, { recursive: true })
const report = { checks: [], pageErrors: [], errors: [] }
const browser = await chromium.launch({ headless: true })
try {
  for (const [width, height] of [[1440, 900], [390, 844], [320, 640]]) {
    const page = await browser.newPage({ viewport: { width, height } })
    page.on('pageerror', error => report.pageErrors.push(error.message))
    const mutations = await installFixture(page)
    await page.goto(process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4181')
    await expect(page.locator('.gc-shell')).toBeVisible()
    if (width < 1024) await page.getByRole('button', { name: 'Открыть навигацию' }).click()
    const category = page.locator('.channel-category').first()
    const openers = [page.getByRole('button', { name: 'Создать категорию или канал', exact: true }),
      category.getByRole('button', { name: /^Создать канал в категории/ })]
    for (const [index, opener] of openers.entries()) {
      await opener.click()
      const dialog = page.locator('.topology-dialog')
      await expect(dialog.locator('input')).toBeFocused()
      const items = dialog.locator('button:not(:disabled), input:not(:disabled), select:not(:disabled)')
      await items.last().focus()
      await page.keyboard.press('Tab')
      await expect(items.first()).toBeFocused()
      await page.keyboard.press('Shift+Tab')
      await expect(items.last()).toBeFocused()
      await page.keyboard.press('Escape')
      await expect(dialog).toHaveCount(0)
      await expect(opener).toBeFocused()
      await expect(page.locator('.nav-drawer')).toBeVisible()
      report.checks.push(`${width}/${index}/tab-loop-escape-return`)
      await opener.click()
      await expect(dialog.locator('input')).toBeFocused()
      await page.evaluate(() => document.fonts.ready)
      await page.screenshot({ path: `${output}/${width}-${index}-modal.png` })
      await dialog.getByRole('button', { name: 'Отмена', exact: true }).click()
      await expect(dialog).toHaveCount(0)
      await expect(opener).toBeFocused()
      report.checks.push(`${width}/${index}/unobstructed-cancel`)
    }
    expect(mutations).toEqual([])
    report.checks.push(`${width}/no-mutation-on-cancel`)
    await page.close()
  }
} catch (error) {
  report.errors.push(error.stack ?? String(error))
} finally {
  await browser.close()
  await writeFile(`${output}/report.json`, JSON.stringify(report, null, 2))
}
console.log(JSON.stringify(report, null, 2))
if (report.errors.length || report.pageErrors.length) process.exitCode = 1
