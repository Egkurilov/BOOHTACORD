import { expect, test } from '@playwright/test'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

test('scenario names stay readable and selecting 1440p chooses the supported text profile', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await page.goto('/tests/screen_profile/quality_dialog.fixture.html')

  const dialog = page.getByRole('dialog')
  await expect(dialog).toBeVisible()
  await expect(dialog.getByRole('heading', { name: 'Демонстрация экрана' })).toBeVisible()
  const scenarios = page.locator('.screen-share-quality__scenario-option')
  await expect(scenarios).toHaveCount(2)
  await scenarios.first().scrollIntoViewIfNeeded()
  await expect(scenarios.nth(0)).toContainText('Плавность')
  await expect(scenarios.nth(0)).toContainText('Игры и видео · 60 FPS')
  await expect(scenarios.nth(1)).toContainText('Чёткость текста')
  await expect(scenarios.nth(1)).toContainText('Документы и код · 15–30 FPS')

  for (const option of await scenarios.all()) {
    const label = option.locator('.screen-share-quality__scenario-title')
    const textStyle = await label.evaluate(element => getComputedStyle(element).whiteSpace)
    expect(textStyle).toBe('normal')
  }

  const resolution1440 = page.getByRole('radio', { name: '1440p' })
  await page.getByText('Дополнительные настройки качества').click()
  await expect(resolution1440).toBeEnabled()
  await expect(page.locator('.screen-share-quality__single-value')).toHaveText('60 FPS')
  const fpsGroup = page.locator('.screen-share-quality__single-value')
  const fpsGroupBox = await fpsGroup.boundingBox()
  const resolutionGroupBox = await page.locator('[aria-label="Верхний предел разрешения трансляции"]').boundingBox()
  expect(fpsGroupBox?.width).toBe(resolutionGroupBox?.width)

  await page.getByRole('radio', { name: '1080p' }).focus()
  await page.keyboard.press('ArrowRight')
  await expect(page.getByRole('radio', { name: /Чёткость текста/ })).toBeChecked()
  await expect(resolution1440).toBeChecked()
  await expect(page.getByRole('radio', { name: '30 FPS', exact: true })).toBeVisible()
  await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') })
  const violations = await page.evaluate(async () => {
    const result = await (window as any).axe.run(document.querySelector('dialog'), {
      runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] },
    })
    return result.violations.map(({ id, impact, nodes }: { id: string; impact: string; nodes: { target: string[] }[] }) => ({
      id, impact, targets: nodes.flatMap(node => node.target),
    }))
  })
  expect(violations).toEqual([])
  await page.screenshot({ path: testInfo.outputPath('screen-share-quality-637x584.png') })

  await page.getByRole('button', { name: 'Начать трансляцию' }).click()
  await expect.poll(() => page.evaluate(() => window.selectedScreenQuality)).toBe('P1440_30')
})
