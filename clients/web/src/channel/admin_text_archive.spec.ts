import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminTextArchive from './AdminTextArchive.vue'

describe('administrator TEXT archive control', () => {
  it('lists only TEXT channels and explains that history remains', async () => {
    const app = createSSRApp(AdminTextArchive, { revision: 7, categories: [{
      id: 'cat-1', name: 'Игры', position: 0, channels: [
        { id: 'text-1', name: 'Общий', kind: 'TEXT', position: 0, admissionClosed: false },
        { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 1, admissionClosed: false },
      ],
    }] })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('Текстовый канал для архивации')
    expect(html).toContain('Общий')
    expect(html).not.toContain('Команда')
    expect(html).toContain('История сообщений сохранится')
    expect(html).toContain('Архивировать канал')
    expect(html).toContain('<dialog')
    expect(html).toContain('Отмена')
  })
})
