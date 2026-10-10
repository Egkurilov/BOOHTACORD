import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import DirectMessageHistoryList from './DirectMessageHistoryList.vue'
import { useDirectMessageStore } from './direct_message_store'

describe('DM history reading order', () => {
  it('shows an empty history only after a successful empty response', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const store = useDirectMessageStore()
    store.historyLoaded = false
    store.error = 'Нет соединения с сервером. Проверьте подключение.'
    const render = async () => {
      const app = createSSRApp(DirectMessageHistoryList, {
        directMessageId: 'dm-1', session: null, otherParticipantId: 'author', otherParticipantDisplayName: 'Автор',
      })
      app.use(pinia)
      return renderToString(app)
    }

    const failed = await render()
    expect(failed).not.toContain('Сообщений пока нет.')

    store.error = null
    store.historyLoaded = true
    const empty = await render()
    expect(empty).toContain('Сообщений пока нет.')
  })

  it('places older messages before newer ones and the pagination control above history', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    useAuthorDirectory().acceptOwnProfile({ account_id: 'author', login: 'author', display_name: 'Автор', role: 'MEMBER' })
    const store = useDirectMessageStore()
    store.messages = [2, 1].map((number) => ({
      id: `message-${number}`, directMessageId: 'dm-1', authorId: 'author', clientMessageId: `client-${number}`,
      body: number === 1 ? 'Первое сообщение' : 'Второе сообщение', revision: 1,
      createdAt: `2026-09-25T10:00:0${number}Z`, deleted: false, attachments: [], mentionUserIds: [],
    }))
    store.nextCursor = 'older-cursor'
    store.historyLoaded = true
    const app = createSSRApp(DirectMessageHistoryList, {
      directMessageId: 'dm-1', session: null, otherParticipantId: 'author', otherParticipantDisplayName: 'Автор',
    })
    app.use(pinia)
    const html = await renderToString(app)

    expect(html.indexOf('Показать предыдущие сообщения')).toBeLessThan(html.indexOf('Первое сообщение'))
    expect(html.indexOf('Первое сообщение')).toBeLessThan(html.indexOf('Второе сообщение'))
  })

  it('shows date dividers before each day of the conversation', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const store = useDirectMessageStore()
    store.messages = [20, 19].map((day) => ({
      id: `message-${day}`, directMessageId: 'dm-1', authorId: 'author', clientMessageId: `client-${day}`,
      body: `День ${day}`, revision: 1, createdAt: new Date(2026, 8, day, 12).toISOString(),
      deleted: false, attachments: [], mentionUserIds: [],
    }))
    const app = createSSRApp(DirectMessageHistoryList, {
      directMessageId: 'dm-1', session: null, otherParticipantId: 'author', otherParticipantDisplayName: 'Автор',
    })
    app.use(pinia)
    const html = await renderToString(app)

    expect(html).toContain('19 сентября 2026')
    expect(html).toContain('20 сентября 2026')
    expect(html.indexOf('19 сентября 2026')).toBeLessThan(html.indexOf('День 19'))
    expect(html.indexOf('20 сентября 2026')).toBeLessThan(html.indexOf('День 20'))
  })
})
