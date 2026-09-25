import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageHistoryList from '../direct_message/DirectMessageHistoryList.vue'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import TextHistoryList from './TextHistoryList.vue'
import { useMessageStore } from './message_store'

const message = { id: 'message-1', authorId: 'author-1', clientMessageId: 'client-1', body: 'Привет',
  createdAt: '2026-09-25T10:00:00Z', revision: 1, deleted: false, attachments: [], mentionUserIds: [] }

async function renderHistory(kind: 'text' | 'dm', nextCursor?: string): Promise<string> {
  const pinia = createPinia()
  setActivePinia(pinia)
  if (kind === 'text') {
    const store = useMessageStore()
    store.channelId = 'text-1'
    store.messages = [{ ...message, channelId: 'text-1' }]
    store.historyLoaded = true
    store.nextCursor = nextCursor
    const app = createSSRApp(TextHistoryList, { channelId: 'text-1', session: null })
    app.use(pinia)
    return renderToString(app)
  }
  const store = useDirectMessageStore()
  store.directMessageId = 'dm-1'
  store.messages = [{ ...message, directMessageId: 'dm-1' }]
  store.historyLoaded = true
  store.nextCursor = nextCursor
  const app = createSSRApp(DirectMessageHistoryList, { directMessageId: 'dm-1', session: null,
    otherParticipantId: 'author-1', otherParticipantDisplayName: 'Автор' })
  app.use(pinia)
  return renderToString(app)
}

describe('first history boundary', () => {
  it.each(['text', 'dm'] as const)('keeps a visible status inside the first date divider for %s', async (kind) => {
    const html = await renderHistory(kind)
    expect(html).toMatch(/class="history-date"[^>]*>.*class="history-start"[^>]*role="status"[^>]*aria-label="Это начало истории\."[^>]*>Начало<\/span>.*<time/s)
    expect(html).not.toContain('<li class="state">Это начало истории.</li>')
  })

  it.each(['text', 'dm'] as const)('retains the older-history action without a false boundary for %s', async (kind) => {
    const html = await renderHistory(kind, 'older-message')
    expect(html).toContain('Показать предыдущие сообщения')
    expect(html).not.toContain('class="history-start"')
  })
})
