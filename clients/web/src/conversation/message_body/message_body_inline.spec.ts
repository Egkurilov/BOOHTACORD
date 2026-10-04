import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../../identity/author_directory'
import MessageItem from '../MessageItem.vue'

describe('published message with a recipient mention', () => {
  it('renders a pill inside the body without a duplicate recipient summary', async () => {
    const pinia = createPinia()
    const directory = useAuthorDirectory(pinia)
    await directory.ensure('daria-id', async () => new Response(JSON.stringify({
      user_id: 'daria-id', login: 'daria', display_name: 'Daria', role: 'MEMBER', presence: 'online',
    })))
    const message = { id: 'message-1', authorId: 'egor-id', clientMessageId: 'client-1',
      body: '@Daria Отлично, увидимся в голосовом!', revision: 1,
      createdAt: '2026-10-03T19:40:00+03:00', deleted: false, mentionUserIds: ['daria-id'] }
    const app = createSSRApp(MessageItem, { message, canEdit: false, canDelete: false })
    app.use(pinia)
    const html = await renderToString(app)
    expect(html).toContain('class="message-mention"')
    expect(html.replace(/<!--.*?-->/g, '')).toContain('@Daria</span> Отлично')
    expect(html).not.toContain('Упомянуты:')
  })
})
