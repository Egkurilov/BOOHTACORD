import { mkdirSync } from 'node:fs'
import { test, expect } from '@playwright/test'

test.beforeEach(async ({ page }) => { await page.goto('/tests/password_generation/fixture.html') })

test('registration generation, confirmation, focus, visibility and mode cleanup', async ({ page }, info) => {
  const generator = page.getByRole('button', { name: 'Сгенерировать пароль' })
  const password = page.getByLabel('Пароль', { exact: true })
  await expect(generator).toHaveCount(0)
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await generator.click()
  expect(await password.evaluate((input: HTMLInputElement) => input.value.length)).toBe(24)
  await expect(password).toHaveAttribute('type', 'text')
  await expect(password).toHaveAttribute('autocomplete', 'new-password')
  await expect(password).toBeFocused()
  await expect(page.getByRole('status')).toHaveText('Надёжный пароль сгенерирован')
  await page.getByRole('button', { name: 'Скрыть пароль' }).click()
  await expect(password).toHaveAttribute('type', 'password')
  if (process.env.PASSWORD_GENERATION_SCREENSHOTS === '1') {
    mkdirSync('../../evidence/qa/issue-104-password-generation', { recursive: true })
    await page.screenshot({ path: `../../evidence/qa/issue-104-password-generation/web-${info.project.name}.png`, fullPage: true })
  }
  await password.fill('manual-password-123')
  await generator.click()
  await expect(page.getByRole('alert')).toHaveText('Заменить введённый пароль сгенерированным?')
  await expect(password).toHaveValue('manual-password-123')
  await page.getByRole('button', { name: 'Оставить', exact: true }).click()
  await expect(password).toHaveValue('manual-password-123')
  await generator.click()
  await page.getByRole('button', { name: 'Заменить', exact: true }).click()
  expect(await password.evaluate((input: HTMLInputElement) => input.value.length === 24 && input.value !== 'manual-password-123')).toBe(true)
  await expect(password).toBeFocused()
  await page.getByRole('button', { name: 'Уже есть аккаунт? Войти' }).click()
  await expect(password).toHaveValue('')
  await expect(password).toHaveAttribute('type', 'password')
  await expect(generator).toHaveCount(0)
  await expect(page.getByRole('status')).toBeEmpty()
})

test('generation fails safely without replacing entered text when crypto fails', async ({ page }) => {
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await page.getByLabel('Пароль', { exact: true }).fill('manual-password-123')
  await page.getByRole('button', { name: 'Сгенерировать пароль' }).click()
  await page.evaluate(() => { crypto.getRandomValues = () => { throw new Error('Unavailable') } })
  await page.getByRole('button', { name: 'Заменить', exact: true }).click()
  await expect(page.getByRole('alert').last()).toContainText('Не удалось безопасно сгенерировать пароль')
  await expect(page.getByLabel('Пароль', { exact: true })).toHaveValue('manual-password-123')
})
