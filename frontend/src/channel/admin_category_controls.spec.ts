import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminCategoryControls from './AdminCategoryControls.vue'

describe('administrator category controls', () => {
  it('offers labelled keyboard-operable reorder and rename controls for the selected category', async () => {
    const app = createSSRApp(AdminCategoryControls, {
      revision: 7, selectedCategoryId: 'cat-b', categories: [
        { id: 'cat-a', name: 'Первая', position: 0, channels: [] },
        { id: 'cat-b', name: 'Вторая', position: 1, channels: [] },
      ],
    })
    const html = await renderToString(app)
    expect(html).toContain('Новое имя категории')
    expect(html).toContain('value="Вторая"')
    expect(html).toContain('aria-label="Переместить категорию «Вторая» выше"')
    expect(html).toContain('aria-label="Переместить категорию «Вторая» ниже"')
    expect(html).toContain('type="button"')
  })
})
