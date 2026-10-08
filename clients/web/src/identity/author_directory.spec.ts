import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAuthorDirectory } from './author_directory'

const member = (name: string, avatar = true) => new Response(JSON.stringify({
  user_id: 'user-2', login: 'member', display_name: name, role: 'MEMBER',
  ...(avatar ? { avatar_url: 'https://attacker.example/track' } : {}),
}))

describe('author directory', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('uses a neutral fallback, deduplicates member lookup and constructs a private avatar URL', async () => {
    const directory = useAuthorDirectory()
    let resolveMember: ((response: Response) => void) | undefined
    const request = vi.fn(() => new Promise<Response>((resolve) => { resolveMember = resolve }))
    expect(directory.displayName('user-2')).toBe('Участник')
    expect(directory.verifiedDisplayName('user-2')).toBeNull()
    expect(directory.avatarUrl('user-2')).toBeUndefined()
    const first = directory.ensure('user-2', request)
    const second = directory.ensure('user-2', request)
    expect(request).toHaveBeenCalledTimes(1)
    resolveMember?.(member('Лера'))
    await Promise.all([first, second])
    expect(directory.displayName('user-2')).toBe('Лера')
    expect(directory.verifiedDisplayName('user-2')).toBe('Лера')
    expect(directory.avatarUrl('user-2')).toBe('/api/v1/members/user-2/avatar')
    expect(directory.avatarUrl('user-2')).not.toContain('attacker.example')
  })

  it('refreshes a renamed member and applies own profile changes immediately', async () => {
    const directory = useAuthorDirectory()
    const request = vi.fn().mockResolvedValueOnce(member('Старое имя', false)).mockResolvedValueOnce(member('Новое имя', false))
    await directory.ensure('user-2', request)
    expect(directory.displayName('user-2')).toBe('Старое имя')
    await directory.refreshKnown(request)
    expect(directory.displayName('user-2')).toBe('Новое имя')
    directory.acceptOwnProfile({ account_id: 'me', login: 'me', display_name: 'Я', role: 'MEMBER' })
    expect(directory.displayName('me')).toBe('Я')
    expect(directory.verifiedDisplayName('me')).toBe('Я')
    expect(request).toHaveBeenCalledTimes(2)
  })

  it('retains the safe fallback when a historic author is unavailable', async () => {
    const directory = useAuthorDirectory()
    await directory.ensure('blocked-user', vi.fn().mockResolvedValue(new Response(null, { status: 404 })))
    expect(directory.displayName('blocked-user')).toBe('Участник')
    expect(directory.verifiedDisplayName('blocked-user')).toBeNull()
    expect(directory.avatarUrl('blocked-user')).toBeUndefined()
  })

  it('does not treat an empty or failed refreshed profile as a verified current voice name', async () => {
    const directory = useAuthorDirectory()
    await directory.ensure('user-2', async () => member('Старое имя'))
    expect(directory.verifiedDisplayName('user-2')).toBe('Старое имя')
    await directory.refreshKnown(async () => member('   '))
    expect(directory.verifiedDisplayName('user-2')).toBeNull()
    await directory.refreshKnown(async () => member('Снова доступен'))
    expect(directory.verifiedDisplayName('user-2')).toBe('Снова доступен')
    await directory.refreshKnown(async () => new Response(null, { status: 503 }))
    expect(directory.verifiedDisplayName('user-2')).toBeNull()
    expect(directory.displayName('user-2')).toBe('Снова доступен')
  })

  it('does not overwrite a newly saved own name with an older member response', async () => {
    const directory = useAuthorDirectory()
    let resolveOld: ((response: Response) => void) | undefined
    const lookup = directory.ensure('me', () => new Promise<Response>((resolve) => { resolveOld = resolve }))
    directory.acceptOwnProfile({ account_id: 'me', login: 'me', display_name: 'Новое имя', role: 'MEMBER' })
    resolveOld?.(new Response(JSON.stringify({ user_id: 'me', login: 'me', display_name: 'Старое имя', role: 'MEMBER' })))
    await lookup
    expect(directory.displayName('me')).toBe('Новое имя')
  })

  it('supersedes an older lookup during refresh and ignores its late response', async () => {
    const directory = useAuthorDirectory()
    const pending: Array<(response: Response) => void> = []
    const request = vi.fn(() => new Promise<Response>((resolve) => pending.push(resolve)))

    const original = directory.ensure('user-2', request)
    const refreshed = directory.refreshKnown(request)
    expect(request).toHaveBeenCalledTimes(2)

    pending[1](member('Новое имя'))
    await refreshed
    expect(directory.displayName('user-2')).toBe('Новое имя')

    pending[0](member('Запоздавшее имя'))
    await original
    expect(directory.displayName('user-2')).toBe('Новое имя')
  })

  it('coalesces overlapping known-profile refreshes into one lookup per member', async () => {
    const directory = useAuthorDirectory()
    const request = vi.fn().mockResolvedValue(member('Актуальное имя'))
    await directory.ensure('user-2', request)
    request.mockClear()

    let resolveRefresh: ((response: Response) => void) | undefined
    request.mockImplementation(() => new Promise<Response>((resolve) => { resolveRefresh = resolve }))
    const first = directory.refreshKnown(request)
    const second = directory.refreshKnown(request)
    expect(request).toHaveBeenCalledTimes(1)

    resolveRefresh?.(member('Новое имя'))
    await Promise.all([first, second])
    expect(directory.displayName('user-2')).toBe('Новое имя')
  })
})
