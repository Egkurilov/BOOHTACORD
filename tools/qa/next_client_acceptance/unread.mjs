import assert from 'node:assert/strict'
import { api, channel, expect, seed, select, sql, status } from './fixture.mjs'
export async function unread(page, browser, fixture, input, report) {
  const results = []
  fixture.a = await channel(page, fixture.category, 'NextUnread')
  const member = await api(page, '/auth/register', 'POST', { login:'qa_unread_member', password:input.password }); status(member,201)
  fixture.member = member.body.id
  const dm = await api(page,'/direct-messages','POST',{participant_id:fixture.member}); status(dm,201); fixture.dm=dm.body.id
  for (const kind of ['CHANNEL','DIRECT_MESSAGE']) {
    const data = seed(fixture, kind)
    const endpoint = kind==='CHANNEL' ? `/channels/${data.scope}/messages` : `/direct-messages/${data.scope}/messages`
    let cursor = data.ids[0], collected = []
    do {
      const result = await api(page, endpoint+'?after='+cursor+'&limit=20'); status(result,200)
      collected.push(...result.body.messages.map(item => item.id)); cursor = result.body.next_cursor
    } while (cursor)
    assert.equal(new Set(collected).size, 120, 'Actual PostgreSQL forward pages lost or duplicated rows')
    const cursorTable = kind==='CHANNEL' ? 'channel_read_cursors' : 'direct_message_read_cursors'
    const cursorTarget = kind==='CHANNEL' ? 'channel_id' : 'direct_message_id'
    sql(`DELETE FROM ${cursorTable} WHERE account_id='${fixture.admin}' AND ${cursorTarget}='${data.scope}'`)
    await page.reload()
    if (kind==='CHANNEL') await select(page, 'NextUnread')
    else {
      await page.getByRole('button', { name: 'Личные', exact: true }).click()
      await page.locator('.direct-message-navigation .channel-button').filter({ hasText: 'qa_unread_member' }).click()
    }
    const read = () => sql(`SELECT COALESCE((SELECT message_id::text FROM ${cursorTable} WHERE account_id='${fixture.admin}' AND ${cursorTarget}='${data.scope}'),'')`)
    await page.getByRole('button', { name: 'К первому непрочитанному', exact: true }).click()
    const context = page.getByTestId('search-message-context')
    await expect(context.getByRole('separator', { name: 'Новые сообщения', exact: true })).toBeVisible()
    await expect(context.locator('[data-search-anchor]')).toHaveAttribute('data-message-id', data.ids[0])
    await expect.poll(read).toBe(data.ids[0])
    for (let i=0; i<6; i++) await context.getByRole('button', { name: 'Показать следующие сообщения', exact: true }).click()
    await expect(context.locator('[data-message-id]')).toHaveCount(121)
    assert.notEqual(read(), data.ids[120], 'Invisible tail was incorrectly marked read')
    const before = read(), background = await browser.newPage()
    await background.bringToFront()
    await expect.poll(() => page.evaluate(() => document.visibilityState)).toBe('hidden')
    await context.locator('.search-context-list').evaluate(list => { list.scrollTop=list.scrollHeight; list.dispatchEvent(new Event('scroll')) })
    await page.waitForTimeout(200)
    assert.equal(read(), before, 'Background tab advanced cursor')
    await background.close(); await page.bringToFront()
    await context.locator('.search-context-list').evaluate(list => list.dispatchEvent(new Event('scroll')))
    await expect.poll(read).toBe(data.ids[120])
    await page.screenshot({ path: input.directory+'/unread-'+kind.toLowerCase()+'.png' })
    await context.getByRole('button', { name: 'К последним сообщениям', exact: true }).click()
    results.push({ kind, postgres_forward_rows:120, browser_context_rows:121, divider:true, own_messages_present:true,
      unseen_tail_retained:true, background_read_blocked:true, visible_tail_advances:true })
  }
  report.unread = results
}
