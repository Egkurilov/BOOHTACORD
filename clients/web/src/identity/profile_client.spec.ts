import { afterEach, describe, expect, it, vi } from 'vitest'
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
    const bitmap = { width: 320, height: 160, close: vi.fn() }
    const drawImage = vi.fn()
    const output = new Blob(['normalized-png'], { type: 'image/png' })
    const canvas = {
      width: 0,
      height: 0,
      getContext: vi.fn().mockReturnValue({ drawImage }),
      toBlob: vi.fn((callback: BlobCallback) => callback(output)),
    }
    vi.stubGlobal('createImageBitmap', vi.fn().mockResolvedValue(bitmap))
    vi.stubGlobal('document', { createElement: vi.fn().mockReturnValue(canvas) })

    await changeOwnPassword('current secure password', 'new secure password', request)
    await uploadAvatar(image, request)
    expect(request).toHaveBeenNthCalledWith(1, expect.stringMatching(/\/me\/password$/), expect.objectContaining({ method: 'POST', credentials: 'same-origin', body: JSON.stringify({ current_password: 'current secure password', new_password: 'new secure password' }) }))
    expect(drawImage).toHaveBeenCalledWith(bitmap, 80, 0, 160, 160, 0, 0, 128, 128)
    expect(canvas.width).toBe(128)
    expect(canvas.height).toBe(128)
    expect(canvas.toBlob).toHaveBeenCalledWith(expect.any(Function), 'image/png')
    expect(bitmap.close).toHaveBeenCalledOnce()
    expect(request).toHaveBeenNthCalledWith(2, expect.stringMatching(/\/me\/avatar$/), expect.objectContaining({ method: 'PUT', credentials: 'same-origin', body: output, headers: expect.objectContaining({ 'content-type': 'image/png' }) }))
  })

  afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals() })

  it('loads members with bounded same-origin pagination', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ members: [], next_cursor: 'next' }), { status: 200 }))
    await expect(loadMembers(undefined, request)).resolves.toEqual({ members: [], next_cursor: 'next' })
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/members\?limit=100$/), expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('parses online/offline presence and treats missing or unknown status as unknown', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ members: [
      { user_id: '1', login: 'online', display_name: 'Online', role: 'MEMBER', presence: 'online' },
      { user_id: '2', login: 'offline', display_name: 'Offline', role: 'MEMBER', presence: 'offline' },
      { user_id: '3', login: 'legacy', display_name: 'Legacy', role: 'MEMBER' },
      { user_id: '4', login: 'unknown', display_name: 'Unknown', role: 'MEMBER', presence: 'away' },
    ] }), { status: 200 }))

    await expect(loadMembers(undefined, request)).resolves.toMatchObject({ members: [
      { user_id: '1', presence: 'online' },
      { user_id: '2', presence: 'offline' },
      { user_id: '3', presence: 'unknown' },
      { user_id: '4', presence: 'unknown' },
    ] })
  })

  it('loads the selected member profile through the authenticated route', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ user_id: 'user-2', login: 'member', display_name: 'Участник', role: 'MEMBER' }), { status: 200 }))
    await expect(loadMember('user-2', request)).resolves.toMatchObject({ user_id: 'user-2', login: 'member' })
    expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/members\/user-2$/), expect.objectContaining({ credentials: 'same-origin' }))
  })
})
