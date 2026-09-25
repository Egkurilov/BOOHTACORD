import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import TextHistoryList from './TextHistoryList.vue'
import { useMessageStore } from './message_store'

describe('TEXT history reading order', () => {
  it('places older messages before newer ones and the pagination control above history', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    useAuthorDirectory().acceptOwnProfile({ account_id: 'author', login: 'author', display_name: 'Автор', role: 'MEMBER' })
    const store = useMessageStore()
    store.messages = [2, 1].map((number) => ({
      id: `message-${number}`, channelId: 'text-1', authorId: 'author', clientMessageId: `client-${number}`,
      body: number === 1 ? 'Первое сообщение' : 'Второе сообщение', revision: 1,
      createdAt: `2026-09-25T10:00:0${number}Z`, deleted: false, attachments: [], mentionUserIds: [],
    }))
    store.nextCursor = 'older-cursor'
    store.historyLoaded = true
    const app = createSSRApp(TextHistoryList, { channelId: 'text-1', session: null })
    app.use(pinia)
    const html = await renderToString(app)

    expect(html.indexOf('Показать предыдущие сообщения')).toBeLessThan(html.indexOf('Первое сообщение'))
    expect(html.indexOf('Первое сообщение')).toBeLessThan(html.indexOf('Второе сообщение'))
  })
})
