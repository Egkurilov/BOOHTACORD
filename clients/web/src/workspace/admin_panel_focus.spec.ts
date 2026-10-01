import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminPanel from './AdminPanel.vue'

describe('administrator panel focus', () => {
  it('provides a programmatic focus destination for the opened panel', async () => {
    const html = await renderToString(createSSRApp(AdminPanel, { categories: [], revision: 0 }))
    expect(html).toContain('id="admin-panel-title" tabindex="-1"')
  })
})
