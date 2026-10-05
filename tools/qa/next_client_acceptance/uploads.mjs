import assert from 'node:assert/strict'
import { expect, select, owned } from './fixture.mjs'
async function reserved() {
  const response = await fetch('http://127.0.0.1:4820/metrics')
  const value = (await response.text()).match(/^voice_platform_attachment_upload_reserved_bytes (\d+)$/m)
  assert.ok(value, 'Actual reservation metric missing'); return Number(value[1])
}
function file(name, size) { return { name, mimeType: 'application/octet-stream', buffer: Buffer.alloc(size) } }
export async function uploads(page, input, report) {
  await select(page, 'NextA')
  const picker = page.locator('.attachment-picker'), queue = picker.locator('[data-upload-status]')
  let count = 0
  page.on('request', request => { if (request.method()==='POST' && /\/attachments$/.test(new URL(request.url()).pathname)) count++ })
  if (input.limited) {
    owned('keeper', 'exec', '$owned', 'dd', 'if=/dev/zero', 'of=/attachments/qa-capacity-fill', 'bs=1000000', 'count=20')
    await page.locator('#message-attachments').setInputFiles([file('one.bin', 5_000_000), file('two.bin', 5_000_000), file('three.bin', 25_000_000)])
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(2)
    await expect(picker.locator('[data-upload-status="failed"]')).toHaveCount(1)
    await page.locator('#message-body').fill('QA attachment queue')
    await expect(page.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeDisabled()
    assert.equal(count, 3)
    owned('keeper', 'exec', '$owned', 'rm', '/attachments/qa-capacity-fill')
    await picker.getByRole('button', { name: 'Повторить загрузку three.bin', exact: true }).click()
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(3)
    assert.equal(count, 4, 'Successful IDs were uploaded again')
    await select(page, 'NextB'); await select(page, 'NextA')
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(3)
    await expect(page.locator('#message-body')).toHaveValue('QA attachment queue')
    await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
    await expect(queue).toHaveCount(0)
    await page.screenshot({ path: input.directory+'/upload-retried-published.png' })
    report.uploads = { actual_third_file_507: true, retry_only_failed: true, prepared_ids_survive_scope: true, published: true }
  } else {
    const session = await page.context().newCDPSession(page)
    await session.send('Network.enable')
    await session.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: 10_000_000, uploadThroughput: 100_000 })
    await page.locator('#message-attachments').setInputFiles(file('cancel.bin', 25_000_000))
    await expect.poll(reserved, { timeout: 15000 }).toBe(25_000_000)
    await expect(picker.locator('progress')).toBeVisible()
    await picker.getByRole('button', { name: 'Отменить загрузку cancel.bin', exact: true }).click()
    await expect.poll(reserved, { timeout: 15000 }).toBe(0)
    assert.equal(owned('keeper', 'exec', '$owned', 'sh', '-c', 'find /attachments/staging -type f | wc -l'), '0')
    await session.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 })
    await session.detach()
    await page.locator('#message-attachments').setInputFiles(Array.from({ length: 10 }, (_, i) => file(`large-${i}.bin`,25_000_000)))
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(10, { timeout: 60000 })
    await expect(page.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeEnabled()
    await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
    await expect(queue).toHaveCount(0)
    await page.getByRole('button', { name: 'Личные', exact: true }).click()
    await page.locator('.direct-message-navigation .channel-button').filter({ hasText: 'qa_next_member' }).click()
    await page.locator('#dm-attachments').setInputFiles(file('dm-real.bin', 1_000_000))
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(1)
    await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
    await expect(queue).toHaveCount(0)
    report.uploads = { actual_abort_releases_reservation: true, staging_files: 0, actual_progress: true,
      ten_25mb_files: true, successful_text_and_dm_publication: true }
  }
}
