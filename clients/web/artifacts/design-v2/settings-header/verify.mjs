import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

export async function verifySettingsHeader(page, geometry) {
  const reference = JSON.parse(readFileSync(process.env.DESIGN_V2_HEADER_REFERENCE, 'utf8').replace(/^\uFEFF/, ''))
  for (const key of Object.keys(reference)) {
    const actual = geometry[key], expected = reference[key]
    for (let index = 0; index < 4; index++) {
      assert.ok(Math.abs(actual.box[index] - expected.box[index]) < 0.05,
        `${key} box[${index}]: ${actual.box[index]} != ${expected.box[index]}`)
    }
    if (actual.box[2]) {
      for (const property of ['fontSize', 'fontWeight', 'lineHeight', 'color', 'strokeWidth', 'strokeLinecap', 'strokeLinejoin']) {
        assert.equal(actual[property], expected[property], `${key}: ${property}`)
      }
    }
  }
  const navigation = page.locator('.settings-workspace-header .workspace-header-toggle--nav')
  if (page.viewportSize().width < 1024) {
    for (const selector of ['.settings-workspace-close', '.settings-workspace-header .workspace-header-toggle--nav']) {
      const box = await page.locator(selector).boundingBox()
      assert.ok(box && box.width >= 44 && box.height >= 44)
    }
    await navigation.click()
    await page.locator('.sidebar.is-open .nav-drawer').waitFor({ state: 'visible' })
    assert.equal(await navigation.getAttribute('aria-expanded'), 'true')
    await page.keyboard.press('Escape')
    await page.locator('.sidebar.is-open').waitFor({ state: 'detached' })
    assert.equal(await navigation.getAttribute('aria-expanded'), 'false')
    assert.equal(await navigation.evaluate(el => el === document.activeElement), true)
  } else assert.equal(await navigation.isVisible(), false)
  assert.equal(await page.locator('.settings-workspace-header').evaluate(el => el.scrollWidth <= el.clientWidth), true)
  return ['source-header-geometry-and-typography', 'responsive-navigation-and-touch-targets', 'header-no-overflow']
}
