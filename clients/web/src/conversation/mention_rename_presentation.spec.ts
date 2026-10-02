import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import MessageItem from './MessageItem.vue'

describe('mention name changes', () => {
  it('renders a new display name while retaining the same recipient ID', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const directory = useAuthorDirectory()
    const member = (name: string) => async () => new Response(JSON.stringify({ user_id: 'user-2', login: 'user2', display_name: name, role: 'MEMBER', presence: 'offline' }))
    await directory.ensure('user-2', member('Лера'))
    const message = { id: 'message-1', authorId: 'user-1', clientMessageId: 'client-1', body: 'Привет', revision: 1,
      createdAt: '2026-09-25T00:00:00Z', deleted: false, mentionUserIds: ['user-2'] }
    const render = async () => {
      const app = createSSRApp(MessageItem, { message, canEdit: false, canDelete: false })
      app.use(pinia)
      return renderToString(app)
    }
    expect(await render()).toContain('@Лера')
    await directory.refreshKnown(member('Валерия'))
    expect(await render()).toContain('@Валерия')
    expect(message.mentionUserIds).toEqual(['user-2'])
  })
})
