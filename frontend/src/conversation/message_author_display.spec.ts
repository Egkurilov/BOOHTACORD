import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import MessageItem from './MessageItem.vue'

describe('message author presentation', () => {
  it('renders a safe display name and private avatar without exposing the author UUID', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    useAuthorDirectory().acceptOwnProfile({ account_id: 'user-2', login: 'member', display_name: 'Лера', role: 'MEMBER', avatar_url: 'https://attacker.example/track' })
    const app = createSSRApp(MessageItem, { message: {
      id: 'message-1', channelId: 'channel-1', authorId: 'user-2', clientMessageId: 'client-1',
      body: 'Привет', createdAt: '2026-09-25T10:00:00Z', revision: 1, deleted: false,
    }, canEdit: false, canDelete: false })
    app.use(pinia)
    const html = await renderToString(app)
    expect(html).toContain('Лера')
    expect(html).toContain('/api/v1/members/user-2/avatar')
    expect(html).not.toContain('attacker.example')
    expect(html).not.toContain('>user-2<')
  })
})
