import assert from 'node:assert/strict'

export async function verifyAudioInteractions(page) {
  const results = []
  await page.getByRole('button', { name: 'По нажатию', exact: true }).click()
  const ptt = page.locator('.audio-ptt-button')
  await ptt.waitFor({ state: 'visible' })
  const panel = await page.locator('.audio-activation-section').boundingBox()
  const assignment = await ptt.boundingBox()
  if (page.viewportSize().width <= 720) assert.ok(assignment.height >= 44, 'Mobile PTT assignment needs a 44px target')
  assert.ok(assignment.y + assignment.height <= panel.y + panel.height - 12, `PTT assignment must fit inside its card: ${JSON.stringify({ panel, assignment })}`)
  const processing = await page.locator('.audio-processing-section').boundingBox()
  assert.ok(processing.y >= panel.y + panel.height + 15, 'Processing panel must follow the expanded activation card')
  if (process.env.DESIGN_V2_SCREENSHOT) await page.screenshot({ path: process.env.DESIGN_V2_SCREENSHOT.replace('.png', '-ptt.png') })
  await page.getByRole('button', { name: 'По голосу', exact: true }).click()
  await ptt.waitFor({ state: 'detached' })
  results.push('ptt-card-expands-and-restores-without-overlap')

  // The connected transport fixture has no microphone track; test the real
  // permission/availability feedback path without requesting a physical device.
  await page.getByRole('button', { name: 'Проверить микрофон', exact: true }).click()
  const feedback = page.locator('.audio-device-check > p[role=status]').first()
  await feedback.waitFor({ state: 'visible' })
  const devicePanel = await page.locator('.audio-device-section').boundingBox()
  const message = await feedback.boundingBox()
  assert.ok(message.y + message.height <= devicePanel.y + devicePanel.height - 12, 'Microphone feedback must fit inside device card')
  const next = await page.locator('.audio-activation-section').boundingBox()
  assert.ok(next.y >= devicePanel.y + devicePanel.height + 15, 'Device feedback must not overlap activation')
  assert.equal(await page.getByRole('meter', { name: 'Уровень микрофона' }).getAttribute('aria-valuenow'), '0')
  if (process.env.DESIGN_V2_SCREENSHOT) await page.screenshot({ path: process.env.DESIGN_V2_SCREENSHOT.replace('.png', '-feedback.png') })
  results.push('real-microphone-feedback-contained-and-zero-meter-preserved')

  const gain = page.getByRole('switch', { name: /Автоматическая громкость/ })
  assert.deepEqual(await gain.locator('..').evaluate(el => {const s = getComputedStyle(el); return [s.fontSize, s.color]}), ['14px', 'rgb(244, 245, 250)'])
  const before = await gain.isChecked()
  await gain.setChecked(!before)
  assert.equal(await gain.isChecked(), !before)
  await gain.setChecked(before)
  results.push('real-processing-toggle-and-restore')
  if (page.viewportSize().width <= 720) {
    const noise = page.getByRole('switch', { name: 'Шумоподавление', exact: true })
    await noise.scrollIntoViewIfNeeded()
    const box = await noise.boundingBox()
    const initial = await noise.getAttribute('aria-checked')
    await page.mouse.click(box.x + box.width / 2, box.y - 5)
    assert.notEqual(await noise.getAttribute('aria-checked'), initial, 'Touch target must extend beyond the 24px switch glyph')
    await noise.click()
    assert.equal(await noise.getAttribute('aria-checked'), initial)
    results.push('noise-switch-expanded-mobile-hit-area')
  }
  return results
}
