import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminChannelOrder from './AdminChannelOrder.vue'

describe('administrator channel order controls', () => {
  it('renders category-scoped channel selection and labelled keyboard buttons', async () => {
    const app = createSSRApp(AdminChannelOrder, { revision: 7, categories: [{
      id: 'cat-a', name: 'Игры', position: 0, channels: [
        { id: 'voice-a', name: 'Голосовой A', kind: 'VOICE', position: 0, admissionClosed: false },
        { id: 'text-b', name: 'Текстовый B', kind: 'TEXT', position: 1, admissionClosed: false },
      ],
    }] })
    const html = await renderToString(app)
    expect(html).toContain('Порядок в разделе')
    expect(html).toContain('Голосовой A')
    expect(html).toContain('Текстовый B')
    expect(html).toContain('aria-label="Переместить канал «Голосовой A» выше"')
    expect(html).toContain('aria-label="Переместить канал «Голосовой A» ниже"')
    expect(html).toContain('type="button"')
  })
})
