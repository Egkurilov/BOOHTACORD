import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import ChannelNavigation from './ChannelNavigation.vue'

describe('channel navigation counters', () => {
  it('shows caller-local TEXT unread and mention badges without adding them to VOICE', async () => {
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      activeVoiceChannelId: undefined, selectedChannelId: undefined, voicePresence: null,
      topology: { revision: 2, categories: [{ id: 'cat-1', name: 'Игры', position: 0, channels: [
        { id: 'text-1', name: 'Общий', kind: 'TEXT', position: 0, admissionClosed: false, unreadCount: 4, mentionCount: 2 },
        { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 1, admissionClosed: false },
      ] }] },
    }))
    expect(html).toContain('aria-label="Непрочитанных сообщений: 4"')
    expect(html).toContain('aria-label="Упоминаний: 2"')
    expect(html.match(/Упоминаний:/g)).toHaveLength(1)
  })
})
