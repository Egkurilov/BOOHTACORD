import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, login, setup } from './fixture.mjs'
import { uploads } from './uploads.mjs'
import { unread } from './unread.mjs'
import { navigation } from './navigation.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
assert.equal(process.env.QA_ORIGIN,'https://localhost:4810')
const browser = await chromium.launch({ headless:true, args:['--allow-loopback-in-peer-connection'] })
try {
  const context = await browser.newContext({ ignoreHTTPSErrors:true, viewport:{width:1440,height:900} })
  context.setDefaultTimeout(20000)
  const page = await context.newPage(), report = { status:'PASS', capacity_limited:input.limited }
  await login(page,'qa_admin',input.password)
  const fixture = await setup(page,input.password)
  await page.reload()
  await uploads(page,input,report,fixture)
  console.log('stage=actual-managed-uploads-accepted')
  if (!input.limited) {
    await unread(page,browser,fixture,input,report)
    console.log('stage=actual-protected-unread-accepted')
    await navigation(page,fixture,input,report)
    console.log('stage=actual-protected-navigation-accepted')
  }
  writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n',{mode:0o600})
} catch (error) {
  let message=String(error).split(input.password).join('[redacted]')
  for (const context of browser.contexts()) for (const cookie of await context.cookies()) message=message.split(cookie.value).join('[redacted]')
  console.error(message); process.exitCode=1
} finally { await browser.close() }
