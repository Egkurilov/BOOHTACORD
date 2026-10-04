import { test, expect } from '@playwright/test'

test.beforeEach(async ({ page }) => { await page.goto('/tests/password_generation/fixture.html') })

test('generation clears old validation, never persists or copies, then authenticates', async ({ page }) => {
  let requests = 0
  let validSecretSent = true
  await page.route('**/api/v1/auth/*', async route => {
    requests++
    const body = route.request().postDataJSON()
    validSecretSent &&= body.login === 'test_member' && /^[A-Za-z0-9!@#$%^&*_+=-]{24}$/.test(body.password)
    await route.fulfill(requests === 1 ? { status: 400, contentType: 'application/json', body: JSON.stringify({ error: { message: 'Предыдущая ошибка' } }) } : { status: 204 })
  })
  await page.evaluate(() => {
    Object.defineProperty(navigator, 'clipboard', { value: { writeText: () => { throw new Error('Unexpected clipboard write') } } })
    Storage.prototype.setItem = () => { throw new Error('Unexpected persistence') }
  })
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await page.getByLabel('Логин').fill('test_member')
  await page.getByLabel('Пароль', { exact: true }).fill('short')
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await expect(page.getByRole('alert')).toContainText('от 12 до 128')
  await page.getByRole('button', { name: 'Сгенерировать пароль' }).click()
  await page.getByRole('button', { name: 'Заменить', exact: true }).click()
  await expect(page.getByRole('alert')).toHaveCount(0)
  expect(requests).toBe(0)
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await expect(page.getByRole('alert')).toHaveText('Предыдущая ошибка')
  await page.getByRole('button', { name: 'Сгенерировать пароль' }).click()
  await page.getByRole('button', { name: 'Заменить', exact: true }).click()
  await expect(page.getByRole('alert')).toHaveCount(0)
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await expect.poll(() => page.evaluate(() => (window as any).authenticatedWithClearedPassword)).toBe(true)
  expect(requests).toBe(3)
  expect(validSecretSent).toBe(true)
  await expect(page.getByLabel('Пароль', { exact: true })).toHaveAttribute('type', 'password')
  expect(await page.evaluate(() => localStorage.length + sessionStorage.length)).toBe(0)
})

test('unmount clears the retained DOM input and suppresses a late authentication result', async ({ page }) => {
  let release!: () => void
  const held = new Promise<void>(resolve => { release = resolve })
  let started = false
  await page.route('**/api/v1/auth/register', async route => { started = true; await held; await route.fulfill({ status: 204 }) })
  let lateLogin = false
  await page.route('**/api/v1/auth/login', async route => { lateLogin = true; await route.fulfill({ status: 204 }) })
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await page.getByLabel('Логин').fill('test_member')
  await page.getByRole('button', { name: 'Сгенерировать пароль' }).click()
  await page.getByRole('button', { name: 'Создать аккаунт' }).click()
  await expect.poll(() => started).toBe(true)
  await expect(page.getByRole('button', { name: 'Сгенерировать пароль' })).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Уже есть аккаунт? Войти' })).toBeDisabled()
  await page.evaluate(() => (window as any).unmountAuthentication())
  expect(await page.evaluate(() => (window as any).retainedPasswordInput.value === '')).toBe(true)
  release()
  await page.waitForResponse('**/api/v1/auth/register')
  expect(lateLogin).toBe(false)
  expect(await page.evaluate(() => (window as any).authenticatedWithClearedPassword)).toBe(false)
})
