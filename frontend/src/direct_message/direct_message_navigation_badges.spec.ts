import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageNavigation from './DirectMessageNavigation.vue'

describe('DM navigation counters', () => {
  it('shows unread and mention counts separately with accessible labels', async () => {
    const app = createSSRApp(DirectMessageNavigation, {
      directMessages: [{ id: 'dm-1', otherParticipantId: 'user-2', otherParticipantDisplayName: 'Лера', createdAt: '2026-09-25T00:00:00Z', unreadCount: 4, mentionCount: 2 }],
      error: null, loading: false,
    })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('aria-label="Непрочитанных личных сообщений: 4"')
    expect(html).toContain('aria-label="Упоминаний в личном диалоге: 2"')
  })
})
