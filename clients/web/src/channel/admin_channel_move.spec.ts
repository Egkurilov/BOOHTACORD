import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminChannelMove from './AdminChannelMove.vue'

describe('administrator channel move form', () => {
  it('shows channel and destination selectors with a disabled same-category move', async () => {
    const app = createSSRApp(AdminChannelMove, { revision: 7, categories: [
      { id: 'cat-a', name: 'Игры', position: 0, channels: [{ id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 0, admissionClosed: false }] },
      { id: 'cat-b', name: 'Общее', position: 1, channels: [] },
    ] })
    const html = await renderToString(app)
    expect(html).toContain('Перенести канал')
    expect(html).toContain('В раздел')
    expect(html).toContain('Команда')
    expect(html).toContain('Канал останется голосовым')
    expect(html).toContain('disabled')
  })
})
