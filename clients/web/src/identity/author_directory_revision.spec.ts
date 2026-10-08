import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAuthorDirectory } from './author_directory'

const member = (name: string, revision: number) => new Response(JSON.stringify({
  user_id: 'user-2', login: 'member', display_name: name, role: 'MEMBER',
  avatar_url: '/api/v1/members/user-2/avatar', profile_revision: revision,
}))

describe('author directory profile revisions', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('invalidates newer metadata and changes only the protected avatar cache key', async () => {
    const directory = useAuthorDirectory()
    await directory.ensure('user-2', vi.fn().mockResolvedValue(member('Старое', 5)))
    expect(directory.avatarUrl('user-2')).toBe('/api/v1/members/user-2/avatar?revision=5')
    const request = vi.fn().mockResolvedValue(member('Новое', 6))
    await directory.invalidate('user-2', 6, request)
    expect(directory.displayName('user-2')).toBe('Новое')
    expect(directory.avatarUrl('user-2')).toBe('/api/v1/members/user-2/avatar?revision=6')
    await directory.invalidate('user-2', 5, request)
    expect(request).toHaveBeenCalledTimes(1)
  })
})
