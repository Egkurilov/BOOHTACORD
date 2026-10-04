import { chromium, expect } from '@playwright/test'
import { mkdir, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { installFixture } from './fixture.mjs'

const output = resolve(process.argv[2] ?? 'artifacts/design-v2/search-feedback-output')
await mkdir(output, { recursive: true })
const browser = await chromium.launch({ headless: true })
const report = { checks: [], states: [], errors: [] }
function check(name, pass) { report.checks.push({ name, pass }) }
try {
  for (const [width, height] of [[1440, 900], [390, 844]]) {
    const page = await browser.newPage({ viewport: { width, height } })
    page.on('pageerror', error => report.errors.push(error.message))
    const fixture = await installFixture(page)
    await page.goto(process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4181')
    await expect(page.locator('.gc-shell')).toBeVisible()
    await page.keyboard.press('Control+k')
    const query = page.getByRole('searchbox', { name: 'Запрос' })
    const status = page.locator('.search-status')
    await expect(query).toBeFocused()
    await page.evaluate(() => document.fonts.ready)
    async function capture(state, selector = '.search-status') {
      const measured = await page.locator(selector).evaluate(element => {
        const style = getComputedStyle(element), bounds = element.getBoundingClientRect()
        const aside = element.closest('.search-aside').getBoundingClientRect()
        return { text: element.textContent, width: bounds.width, height: bounds.height, x: bounds.x,
          color: style.color, size: style.fontSize, lineHeight: style.lineHeight, clip: style.clipPath,
          position: style.position, contained: bounds.x >= aside.x && bounds.right <= aside.right }
      })
      report.states.push({ width, state, ...measured })
      await page.screenshot({ path: `${output}/${width}-${state}.png` })
      return measured
    }
    function visible(state, measured, color = 'rgb(182, 189, 206)') {
      check(`${width}/${state}/readable`, measured.width > 100 && measured.height >= 20 && measured.clip === 'none')
      check(`${width}/${state}/contained`, measured.contained)
      check(`${width}/${state}/type-color`, measured.color === color && measured.size === '14px' && measured.lineHeight === '20px')
    }
    visible('idle', await capture('idle'))
    async function submit() {
      const count = fixture.requests()
      await query.fill('тест')
      await query.press('Enter')
      await expect.poll(fixture.requests).toBe(count + 1)
      await expect(status).toHaveText('Ищем сообщения…')
    }
    await submit()
    visible('loading', await capture('loading'))
    check(`${width}/pending-controls`, await query.isDisabled() && await page.getByRole('combobox').isDisabled())
    fixture.finish('empty')
    await expect(status).toHaveText('Совпадений нет.')
    visible('empty', await capture('empty'))
    await submit()
    fixture.finish('error')
    await expect(page.locator('#search-error')).toBeVisible()
    visible('error', await capture('error', '#search-error'), 'rgb(239, 68, 68)')
    check(`${width}/error-query-association`, await query.getAttribute('aria-describedby') === 'search-error')
    await submit()
    fixture.finish('results')
    await expect(page.locator('.search-result')).toHaveCount(1)
    const success = await capture('results')
    check(`${width}/results-single-visible-count`, success.clip !== 'none' && await page.locator('.search-result-count').isVisible())
    check(`${width}/retry-clears-error`, await page.locator('#search-error').count() === 0)
    await submit()
    await page.keyboard.press('Escape')
    await expect(page.locator('.search-panel')).toHaveCount(0)
    await page.keyboard.press('Control+k')
    await expect(query).toBeFocused()
    const response = page.waitForResponse('**/search/messages?*')
    fixture.finish('results')
    await response
    await expect(status).toHaveText('Введите запрос и нажмите Enter.')
    check(`${width}/old-response-ignored`, await page.locator('.search-result').count() === 0)
    await page.close()
  }
} catch (error) {
  report.errors.push(error.stack ?? String(error))
} finally {
  await browser.close()
  await writeFile(`${output}/report.json`, JSON.stringify(report, null, 2))
}
const failed = report.checks.filter(check => !check.pass)
console.log(JSON.stringify({ checks: report.checks.length, failed, errors: report.errors, output }, null, 2))
if (failed.length || report.errors.length) process.exitCode = 1
