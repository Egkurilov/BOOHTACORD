import { test,expect } from '@playwright/test'
const owner='00000000-0000-4000-8000-000000000001',channel='00000000-0000-4000-8000-000000000002'
test('lost POST response reconciles once and another client sees one row',async({page,browser})=>{
 let stored:any=null,posts=0,lookups=0
 const handler=async(route:any)=>{
  const request=route.request(),url=request.url()
  if(url.includes('/members/')){await route.fulfill({json:{user_id:owner,login:'fixture',display_name:'Fixture',role:'MEMBER',presence:'online'}});return}
  if(request.method()==='POST'){
   posts++;const body=request.postDataJSON();stored={id:'00000000-0000-4000-8000-000000000003',channel_id:channel,author_id:owner,client_message_id:body.client_message_id,body:body.body,revision:1,created_at:'2026-10-05T00:00:00Z',attachments:[],mention_user_ids:[]}
   await route.abort('connectionreset');return
  }
  if(url.includes('/message-delivery/')){lookups++;await route.fulfill({json:{account_id:owner,message_id:stored?.id??null}});return}
  await route.fulfill({json:{messages:stored?[stored]:[]}})
 }
 await page.route('**/api/v1/**',handler);await page.goto('/tests/delivery_uncertainty/fixture.html')
 await page.getByRole('button',{name:'Отправить',exact:true}).click()
 await expect(page.locator('.message-row')).toHaveCount(1)
 await expect(page.getByText('Отправляется…')).toHaveCount(0)
 await expect.poll(()=>lookups).toBe(1);expect(posts).toBe(1)
 const peer=await browser.newContext();const second=await peer.newPage()
 await second.route('**/api/v1/**',handler);await second.goto('http://127.0.0.1:4807/tests/delivery_uncertainty/fixture.html')
 await expect(second.locator('.message-row')).toHaveCount(1);expect(posts).toBe(1);await peer.close()
})
test('403 keeps a local failed row; discard makes no DELETE',async({page})=>{
 let deletes=0,lookups=0
 await page.route('**/api/v1/**',async route=>{
  const request=route.request();if(request.method()==='DELETE')deletes++
  if(request.url().includes('/message-delivery/'))lookups++
  await route.fulfill({status:request.method()==='POST'?403:200,json:request.method()==='POST'?{error:{code:'FORBIDDEN'}}:{messages:[]}})
 })
 await page.goto('/tests/delivery_uncertainty/fixture.html');await page.getByRole('button',{name:'Отправить',exact:true}).click()
 await expect(page.getByText('Не отправлено',{exact:true})).toBeVisible()
 await expect(page.getByRole('button',{name:'Повторить отправку'})).toBeDisabled()
 await page.getByRole('button',{name:'Убрать из очереди'}).click()
 await expect(page.locator('.message-row')).toHaveCount(0);expect(deletes).toBe(0);expect(lookups).toBe(0)
})
