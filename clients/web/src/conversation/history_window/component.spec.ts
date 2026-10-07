import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import { useAuthorDirectory } from '../../identity/author_directory'
import { useMessageStore } from '../message_store'
import TextHistoryList from '../TextHistoryList.vue'

describe('virtual history component', () => {
  it('renders only a viewport-sized slice when the loaded history has ten thousand messages', async () => {
    const pinia = createPinia(); setActivePinia(pinia)
    useAuthorDirectory().acceptOwnProfile({ account_id: 'author', login: 'author', display_name: 'Автор', role: 'MEMBER' })
    useMessageStore().$patch({ historyLoaded: true, nextCursor: 'older-cursor', messages: Array.from({ length: 10000 }, (_, index) => ({
      id: `message-${index}`, channelId: 'text-1', authorId: 'author', clientMessageId: `client-${index}`, body: `Текст ${index}`,
      revision: 1, createdAt: `2026-09-17T12:${String(Math.floor(index / 60) % 60).padStart(2, '0')}:${String(index % 60).padStart(2, '0')}Z`, deleted: false, attachments: [], mentionUserIds: [],
    })) })
    const app = createSSRApp(TextHistoryList, { channelId: 'text-1', session: null }); app.use(pinia)

    const html = await renderToString(app)

    expect(html.match(/data-message-id=/g)?.length ?? 0).toBeLessThan(40)
    expect(html).toContain('Показать предыдущие сообщения')
  })
})
