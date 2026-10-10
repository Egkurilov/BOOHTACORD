import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminPanel from './AdminPanel.vue'

describe('administrator panel context', () => {
  it('labels the admin panel with a semantic heading and names its sections', async () => {
    const html = await renderToString(createSSRApp(AdminPanel, { categories: [], revision: 0 }))
    expect(html).toContain('aria-labelledby="admin-panel-title"')
    expect(html).toContain('<h1 id="admin-panel-title">Администрирование</h1>')
    expect(html).toContain('aria-label="Разделы администрирования"')
    expect(html).toMatch(/aria-current="page"[^>]*>Участники<\/button>/)
  })
})
