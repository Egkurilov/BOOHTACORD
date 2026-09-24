import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminVoiceClose from './AdminVoiceClose.vue'

describe('administrator VOICE close control', () => {
  it('lists only VOICE channels and describes pending media removal', async () => {
    const app = createSSRApp(AdminVoiceClose, { revision: 7, categories: [{
      id: 'cat-1', name: 'Игры', position: 0, channels: [
        { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 0, admissionClosed: false },
        { id: 'text-1', name: 'Общий', kind: 'TEXT', position: 1, admissionClosed: false },
      ],
    }] })
    const html = await renderToString(app)
    expect(html).toContain('Команда')
    expect(html).not.toContain('Общий')
    expect(html).toContain('SFU')
    expect(html).toContain('Закрыть вход')
  })
})
