import { createSSRApp } from 'vue'
import { createPinia } from 'pinia'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminTopologyControls from './AdminTopologyControls.vue'
import AdminChannelRename from './AdminChannelRename.vue'
import AdminChannelMove from './AdminChannelMove.vue'
import AdminChannelOrder from './AdminChannelOrder.vue'

const categories = [
  { id: 'cat-a', name: 'Игры', position: 0, channels: [
    { id: 'voice-a', name: 'Команда', kind: 'VOICE' as const, position: 0, admissionClosed: false },
  ] },
  { id: 'cat-b', name: 'Общее', position: 1, channels: [] },
]

describe('administrator topology inspector', () => {
  it('renders one selectable tree beside the selected-object inspector', async () => {
    const app = createSSRApp(AdminTopologyControls, { categories, revision: 7 })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('Структура разделов и каналов')
    expect(html).toContain('admin-topology-inspector')
    expect(html).toContain('Выбрать голосовой канал Команда')
  })

  it('binds channel editors to the selected ID without duplicate object selects', async () => {
    for (const [component, visible] of [
      [AdminChannelRename, 'Команда'], [AdminChannelMove, 'голосовым'], [AdminChannelOrder, 'Команда'],
    ] as const) {
      const html = await renderToString(createSSRApp(component, { categories, revision: 7, channelId: 'voice-a' }))
      expect(html).not.toContain('name="rename-channel"')
      expect(html).not.toContain('name="move-channel"')
      expect(html).not.toContain('name="order-channel"')
      expect(html).toContain(visible)
    }
  })
})
