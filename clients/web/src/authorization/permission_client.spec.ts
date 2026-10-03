import { describe, expect, it } from 'vitest'
import { loadPermissions } from './permission_client'

describe('permission client', () => {
  it('parses the exact six permission snapshot', async () => {
    const request = async () => new Response(JSON.stringify({ account_id: 'member-1', role: 'MEMBER', permissions_revision: 2, permissions: { 'channel.text.create': true, 'channel.text.delete': false, 'channel.voice.create': true, 'channel.voice.delete': false, 'category.create': true, 'category.delete': false } }), { status: 200 })
    await expect(loadPermissions(request)).resolves.toMatchObject({ accountId: 'member-1', revision: 2 })
  })
  it('rejects missing or unknown grants', async () => {
    const request = async () => new Response(JSON.stringify({ account_id: 'member-1', role: 'MEMBER', permissions_revision: 2, permissions: { 'channel.text.create': true } }), { status: 200 })
    await expect(loadPermissions(request)).rejects.toThrow('некорректные разрешения')
  })
})
