import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import { avatarFallbackStyle } from './avatar_fallback'
import MessageItem from './MessageItem.vue'

async function renderMessage(authorId: string, kind: 'text' | 'dm', avatarUrl?: string): Promise<string> {
  const pinia = createPinia()
  setActivePinia(pinia)
  useAuthorDirectory().acceptOwnProfile({ account_id: authorId, login: 'member', display_name: 'Лера', role: 'MEMBER', avatar_url: avatarUrl })
  const message = { id: 'message-1', authorId, clientMessageId: 'client-1', body: 'Привет',
    createdAt: '2026-09-25T10:00:00Z', revision: 1, deleted: false,
    ...(kind === 'text' ? { channelId: 'channel-1' } : { directMessageId: 'dm-1' }) }
  const app = createSSRApp(MessageItem, { message, canEdit: false, canDelete: false })
  app.use(pinia)
  return renderToString(app)
}

describe('message fallback avatar', () => {
  it('uses stable distinct pastel styles for author IDs, independent of message location', async () => {
    const first = avatarFallbackStyle('author-one')
    const second = avatarFallbackStyle('author-two')
    expect(first).toEqual(avatarFallbackStyle('author-one'))
    expect(second).not.toEqual(first)
    expect(first.backgroundColor).toMatch(/^#[0-9a-f]{6}$/)
    expect(first.color).toMatch(/^#[0-9a-f]{6}$/)

    for (const kind of ['text', 'dm'] as const) {
      const html = await renderMessage('author-one', kind)
      expect(html).toContain('class="message-avatar"')
      expect(html).toContain(`background-color:${first.backgroundColor}`)
      expect(html).toContain(`color:${first.color}`)
      expect(html).toContain('>Л</span>')
    }
  })

  it('keeps a private uploaded avatar image instead of styling a fallback', async () => {
    const html = await renderMessage('author-one', 'dm', '/ignored-public-url')
    expect(html).toContain('<img')
    expect(html).toContain('/api/v1/members/author-one/avatar')
    expect(html).not.toContain(`background-color:${avatarFallbackStyle('author-one').backgroundColor}`)
  })
})
