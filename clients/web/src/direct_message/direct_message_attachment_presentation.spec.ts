import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import MessageItem from '../conversation/MessageItem.vue'
import DirectMessageConversation from './DirectMessageConversation.vue'

const message = { id: 'message-a', directMessageId: 'dm/a', authorId: 'peer', clientMessageId: 'client-a',
  body: 'Файл', createdAt: '2026-09-25T10:00:00Z', revision: 1, deleted: false,
  attachments: [{ id: 'file ?#', originalName: 'safe.png', sizeBytes: 4 }] }

describe('DM attachment presentation', () => {
  it('uses protected encoded download and preview URLs for a live file', async () => {
    const app = createSSRApp(MessageItem, { message, canEdit: false, canDelete: false })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('/api/v1/direct-messages/dm%2Fa/attachments/file%20%3F%23')
    expect(html).toContain('/api/v1/direct-messages/dm%2Fa/attachments/file%20%3F%23/preview')
    expect(html).toContain('Скачать safe.png')
  })

  it('does not render links on a deleted message and offers the DM picker', async () => {
    const app = createSSRApp(MessageItem, { message: { ...message, deleted: true, body: '' }, canEdit: false, canDelete: false })
    app.use(createPinia())
    expect(await renderToString(app)).not.toContain('/attachments/')
    const conversation = createSSRApp(DirectMessageConversation, { directMessageId: 'dm-a', otherParticipantId: 'peer', otherParticipantDisplayName: 'Лера', navOpen: false })
    conversation.use(createPinia())
    expect(await renderToString(conversation)).toContain('Прикрепить файлы')
  })
})
