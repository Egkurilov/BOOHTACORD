import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, api, channel, expect, login, status } from '../client_lifecycle/request.mjs'
import { bursts } from '../critical_client_acceptance/bursts.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
const browser = await chromium.launch({ headless: true })
try {
  const a = await (await browser.newContext({ ignoreHTTPSErrors: true })).newPage()
  const b = await (await browser.newContext({ ignoreHTTPSErrors: true })).newPage()
  for (const page of [a, b]) { page.setDefaultTimeout(15000); await login(page, 'qa_admin', input.password) }
  const category = await api(a, '/admin/categories', 'POST', { name: 'BaselineLab' }); status(category, 201)
  const target = await api(a, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'WelcomeLab', kind: 'TEXT' }); status(target, 201)
  await expect(a.locator('.channel-button').filter({ hasText: 'WelcomeLab' })).toBeVisible()
  await channel(a); await channel(b)
  const report = { status: 'PASS', mocks: false, actual_api: true }
  await bursts(a, b, target.body.id, report, input.directory, true)
  writeFileSync(input.directory+'/report.json', JSON.stringify(report, null, 2)+'\n')
} catch (error) {
  let message = String(error)
  const secrets = [input.password]
  for (const context of browser.contexts()) secrets.push(...(await context.cookies()).map(cookie => cookie.value))
  for (const value of secrets.filter(Boolean)) message = message.split(value).join('[redacted]')
  console.error('Previous native client measurement failed: '+message.slice(0, 2000))
  process.exitCode = 1
} finally { await browser.close() }
