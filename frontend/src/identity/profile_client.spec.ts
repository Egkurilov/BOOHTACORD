import { describe, expect, it, vi } from 'vitest'
import { changeOwnPassword, loadMember, loadMembers, loadOwnProfile, saveOwnProfile, uploadAvatar } from './profile_client'

describe('signed-in profile API client', () => {
  it('loads and saves only the caller profile with same-origin cookies', async () => {
    const request = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ account_id: 'user-1', login: 'fixed', display_name: 'Имя', role: 'MEMBER' }), { status: 200 })).mockResolvedValueOnce(new Response(JSON.stringify({ account_id: 'user-1', login: 'fixed', display_name: 'Новое имя', role: 'MEMBER' }), { status: 200 }))
    await expect(loadOwnProfile(request)).resolves.toMatchObject({ account_id: 'user-1', login: 'fixed' })
    await expect(saveOwnProfile('Новое имя', request)).resolves.toMatchObject({ display_name: 'Новое имя' })
    expect(request).toHaveBeenNthCalledWith(1, expect.stringMatching(/\/me$/), expect.objectContaining({ method: 'GET', credentials: 'same-origin' }))
    expect(request).toHaveBeenNthCalledWith(2, expect.stringMatching(/\/me$/), expect.objectContaining({ method: 'PATCH', credentials: 'same-origin', body: JSON.stringify({ display_name: 'Новое имя' }) }))
  })

  it('uses the documented password and private avatar operations', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))
    const image = new File(['png'], 'avatar.png', { type: 'image/png' })
    await changeOwnPassword('current secure password', 'new secure password', request)
    await uploadAvatar(image, request)
    expect(request).toHaveBeenNthCalledWith(1, expect.stringMatching(/\/me\/password$/), expect.objectContaining({ method: 'POST', credentials: 'same-origin', body: JSON.stringify({ current_password: 'current secure password', new_password: 'new secure password' }) }))
    expect(request).toHaveBeenNthCalledWith(2, expect.stringMatching(/\/me\/avatar$/), expect.objectContaining({ method: 'PUT', credentials: 'same-origin', body: image, headers: expect.objectContaining({ 'content-type': 'image/png' }) }))
  })

  it('loads members with bounded same-origin pagination', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ members: [], next_cursor: 'next' }), { status: 200 }))
    await expect(loadMembers(undefined, request)).resolves.toEqual({ members: [], next_cursor: 'next' })
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/members\?limit=100$/), expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('loads the selected member profile through the authenticated route', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ user_id: 'user-2', login: 'member', display_name: 'Участник', role: 'MEMBER' }), { status: 200 }))
    await expect(loadMember('user-2', request)).resolves.toMatchObject({ user_id: 'user-2', login: 'member' })
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/members\/user-2$/), expect.objectContaining({ credentials: 'same-origin' }))
  })
})
