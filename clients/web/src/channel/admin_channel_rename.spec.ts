import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminChannelRename from './AdminChannelRename.vue'

describe('administrator channel rename form', () => {
  it('shows the current channel name and immutable kind in the accessible form', async () => {
    const app = createSSRApp(AdminChannelRename, { revision: 8, categories: [{
      id: 'cat-1', name: 'Игры', position: 0, channels: [
        { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 0, admissionClosed: false },
      ],
    }] })
    const html = await renderToString(app)
    expect(html).toContain('Новое имя канала')
    expect(html).toContain('value="Команда"')
    expect(html).toContain('Тип: голосовой')
    expect(html).toContain('Переименовать канал')
    expect(html).not.toContain('name="channel-kind"')
  })
})
