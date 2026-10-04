import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { mkdirSync, writeFileSync } from 'node:fs'
const output = process.argv[2]
assert.ok(output, 'Output directory required')
mkdirSync(output, { recursive: true })
const browser = await chromium.launch({ headless: true })
const results = []
try {
  for (const width of [1440, 390, 320]) {
    const page = await browser.newPage({ viewport: { width, height: 900 } })
    const errors = []; page.on('pageerror', error => errors.push(error.message))
    await page.goto(`${process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4181'}/artifacts/design-v2/voice-dock/fixture.html`)
    const dock = page.locator('.voice-dock')
    await dock.waitFor({ state: 'visible' })
    const checks = []
    const set = async changes => { await page.evaluate(changes => Object.assign(window.dockFixture.props, changes), changes) }
    const enabled = dock.getByRole('button', { name: 'Выключить микрофон', exact: true })
    await enabled.click()
    await dock.getByRole('button', { name: 'Включить микрофон', exact: true }).click()
    await set({ activationMode: 'PTT' }); assert.equal(await enabled.isDisabled(), true)
    await set({ activationMode: 'VAD' })
    await dock.getByRole('button', { name: 'Выключить удалённый звук', exact: true }).click()
    assert.equal(await enabled.isDisabled(), true)
    await dock.getByRole('button', { name: 'Включить удалённый звук', exact: true }).click()
    assert.equal(await enabled.isEnabled(), true)
    checks.push('microphone-events-ptt-deafen-guards')
    await dock.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true }).click()
    await dock.getByRole('button', { name: 'Остановить демонстрацию экрана', exact: true }).click()
    await set({ state: 'RECONNECTING' })
    assert.equal(await dock.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true }).isDisabled(), true)
    assert.equal(await dock.getByRole('status').textContent(), 'Восстанавливаем голосовое соединение')
    await set({ state: 'CONNECTED', pingMs: 42 })
    assert.match(await dock.locator('.voice-quality').getAttribute('aria-label'), /42 мс/)
    if (width >= 1024) assert.ok((await dock.locator('.voice-quality').boundingBox()).width > 1)
    await set({ pingMs: null, connectionQuality: 'POOR' })
    if (width >= 1024) assert.ok((await dock.locator('.voice-quality').boundingBox()).width > 1)
    checks.push('share-start-stop-reconnect-guard', 'measured-and-poor-quality-preserved')
    await page.getByRole('button', { name: 'Открыть настройки профиля' }).click()
    await page.getByRole('button', { name: 'Настройки аудио', exact: true }).click()
    await page.locator('.user-footer-presence').waitFor()
    await page.evaluate(() => { window.dockFixture.account.online = false })
    await page.locator('.user-footer-presence').waitFor({ state: 'detached' })
    if (width < 720) for (const button of await dock.locator('button').all()) {
      const box = await button.boundingBox(); assert.ok(box.width >= 44 && box.height >= 44)
    }
    checks.push('profile-settings-events-and-live-presence', 'mobile-hit-targets')
    if (width < 720) {
      await page.locator('.sidebar').evaluate(element => element.classList.remove('is-open'))
      assert.equal(await dock.locator('button').first().evaluate(element => getComputedStyle(element).backgroundColor), 'rgba(0, 0, 0, 0)')
      await page.locator('.sidebar').evaluate(element => element.classList.add('is-open'))
      checks.push('compact-mobile-microphone-stays-transparent')
    }
    await set({ state: 'LEAVING' })
    assert.equal(await dock.getByRole('button', { name: 'Выйти из голосового канала' }).isDisabled(), true)
    await set({ state: 'CONNECTED', channel: null })
    await dock.getByRole('button', { name: 'Выйти из голосового канала' }).click()
    assert.deepEqual(await page.evaluate(() => window.dockFixture.events), ['microphone', 'microphone', 'deafen', 'deafen', 'startScreen', 'stopScreen', 'profile', 'settings', 'leave'])
    assert.deepEqual(errors, [])
    checks.push('orphan-session-manual-exit')
    results.push({ width, checks, errors })
    await page.close()
  }
  writeFileSync(`${output}/report.json`, JSON.stringify(results, null, 2))
  console.log(JSON.stringify(results))
} finally { await browser.close() }
