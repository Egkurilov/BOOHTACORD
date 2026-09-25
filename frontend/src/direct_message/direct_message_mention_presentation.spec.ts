import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageConversation from './DirectMessageConversation.vue'

describe('DM mention composer', () => {
  it('offers the peer by name as the only mention recipient', async () => {
    const app = createSSRApp(DirectMessageConversation, { directMessageId: 'dm-1', otherParticipantId: 'user-2', otherParticipantDisplayName: 'Лера', navOpen: false })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('Упоминания')
    expect(html).toContain('Лера')
    expect(html).not.toContain('Загрузить участников')
  })
})
