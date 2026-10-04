import assert from 'node:assert/strict'

export async function openReferenceCategoryMenu(page) {
  const heading = page.locator('.channel-category > h2').first()
  await heading.waitFor({ state: 'visible' })
  const box = await heading.boundingBox()
  assert.ok(box && box.width > 2 && box.height > 2, 'Category heading must have a clickable area')
  // Keep the canonical pointer where it is inside the live heading; clamp otherwise.
  // The resulting menu displacement is retained in the raw screenshot/diff.
  const x = Math.max(1, Math.min(255 - box.x, box.width - 1))
  const y = Math.max(1, Math.min(235 - box.y, box.height - 1))
  await heading.click({ button: 'right', position: { x, y } })
  const menu = page.locator('.category-context-menu')
  await menu.waitFor({ state: 'visible' })
  assert.equal(await menu.getByRole('menuitem').count(), 4)
  assert.equal(await menu.getByRole('menuitem', { name: 'Удалить раздел...' }).isDisabled(), true)
  const menuBox = await menu.boundingBox()
  assert.ok(menuBox && Math.abs(menuBox.x - (box.x + x)) < 1 && Math.abs(menuBox.y - (box.y + y)) < 1,
    'Menu must be anchored at the real context-menu pointer')
}
