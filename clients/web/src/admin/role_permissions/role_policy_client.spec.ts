import { describe, expect, it, vi } from 'vitest'

import { loadRolePolicies, saveMemberPolicy } from './role_policy_client'

const values = {
  'channel.text.create': true, 'channel.text.delete': false,
  'channel.voice.create': true, 'channel.voice.delete': false,
  'category.create': true, 'category.delete': false,
}

describe('role policy client', () => {
  it('loads the exact administrator and member policies', async () => {
    const request = vi.fn(async (_input: string, _init: RequestInit) => new Response(JSON.stringify({ revision: 4, roles: [
      { role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions: Object.fromEntries(Object.keys(values).map((key) => [key, true])) },
      { role: 'MEMBER', display_name: 'Пользователь', editable: true, permissions: values },
    ] }), { status: 200 }))
    const result = await loadRolePolicies(request)
    expect(result.revision).toBe(4)
    expect(result.roles[1]?.permissions).toEqual(values)
  })

  it('sends a complete revision guarded update and exposes conflicts', async () => {
    const request = vi.fn(async (_input: string, _init: RequestInit) => new Response(JSON.stringify({ error: { code: 'PERMISSIONS_REVISION_CONFLICT', message: 'Изменено' } }), { status: 409 }))
    await expect(saveMemberPolicy(4, values, true, request)).rejects.toMatchObject({ code: 'PERMISSIONS_REVISION_CONFLICT', status: 409 })
    expect(JSON.parse(request.mock.calls[0]![1].body as string)).toEqual({ expected_revision: 4, permissions: values, confirm_delete_grants: true })
  })
})
