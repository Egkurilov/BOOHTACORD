import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminTopologyTree from './AdminTopologyTree.vue'

describe('administrator topology tree', () => {
  it('shows categories and channels in position order with one selected object', async () => {
    const html = await renderToString(createSSRApp(AdminTopologyTree, {
      selectedId: 'voice-1', categories: [
        { id: 'cat-b', name: 'Игры', position: 2, channels: [
          { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 1, admissionClosed: false },
          { id: 'text-1', name: 'Новости', kind: 'TEXT', position: 0, admissionClosed: false },
        ] },
        { id: 'cat-a', name: 'Общее', position: 0, channels: [] },
      ],
    }))
    expect(html.indexOf('Общее')).toBeLessThan(html.indexOf('Игры'))
    expect(html.indexOf('Новости')).toBeLessThan(html.indexOf('Команда'))
    expect(html).toContain('aria-label="Выбрать текстовый канал Новости"')
    expect(html).toContain('aria-label="Выбрать голосовой канал Команда"')
    expect(html).toMatch(/aria-current="true"[^>]*aria-label="Выбрать голосовой канал Команда"/)
  })
})
