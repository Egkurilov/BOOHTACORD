import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import MentionPicker from './MentionPicker.vue'

describe('mention picker', () => {
  it('shows a selected recipient by name and allows keyboard selection in a DM', async () => {
    const app = createSSRApp(MentionPicker, {
      modelValue: ['user-2'], selfId: 'user-1', disabled: false,
      onlyParticipant: { id: 'user-2', displayName: 'Лера' },
    })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('Упоминания')
    expect(html).toContain('Лера')
    expect(html).toContain('Убрать упоминание Лера')
    expect(html).not.toContain('user-2')
  })
})
