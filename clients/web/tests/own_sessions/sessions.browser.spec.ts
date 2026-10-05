import { expect, test } from '@playwright/test'
const owner='00000000-0000-4000-8000-000000000001',current='00000000-0000-4000-8000-000000000002',other='00000000-0000-4000-8000-000000000003'
const row=(id:string)=>({id,label:'Вход в приложение',created_at:'2026-10-05T00:00:00Z',last_active_at:'2026-10-05T01:00:00Z',current:id===current})
test('real component revokes others, refreshes on hints and fits the viewport',async({page})=>{
  let sessions=[row(current),row(other)], reads=0
  await page.route('**/api/v1/me/sessions**',async route=>{
    const request=route.request()
    if(request.method()==='GET'){reads++;await route.fulfill({json:{account_id:owner,sessions,next_cursor:null}});return}
    expect(request.headers()['x-account-id']).toBe(owner)
    expect(request.method()).toBe('POST');expect(request.url()).toContain('/revoke-others')
    sessions=[row(current)];await route.fulfill({status:204})
  })
  await page.goto('/tests/own_sessions/fixture.html')
  await expect(page.getByTestId('session-revoke')).toHaveCount(2)
  await expect(page.getByTestId('session-revoke').first()).toBeDisabled()
  await page.getByTestId('sessions-revoke-others').click()
  await expect(page.getByTestId('session-revoke')).toHaveCount(1)
  await page.evaluate(()=>{(window as any).sessionHint()})
  await expect.poll(()=>reads).toBe(3)
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true)
})
test('cookie account mismatch hides rows and reports session expiry',async({page})=>{
  await page.route('**/api/v1/me/sessions',route=>route.fulfill({json:{account_id:other,sessions:[row(current)],next_cursor:null}}))
  await page.goto('/tests/own_sessions/fixture.html')
  await expect(page.getByRole('alert')).toContainText('Аккаунт изменился')
  await expect(page.getByTestId('session-revoke')).toHaveCount(0)
  await expect.poll(()=>page.evaluate(()=>(window as any).expired)).toBe(true)
})
