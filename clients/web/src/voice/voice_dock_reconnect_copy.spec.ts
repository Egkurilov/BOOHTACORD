import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import VoiceDock from './VoiceDock.vue'

describe('VOICE dock helper copy', () => {
  it('keeps the connected channel and controls without helper text', async () => {
    const html = await renderToString(createSSRApp(VoiceDock, {
      channel: {
        id: 'voice', name: 'Voice', kind: 'VOICE', position: 0,
        admissionClosed: false,
      },
      activeSession: true, error: null, activationMode: 'VAD', deafened: false,
      deafenChanging: false, microphoneMuted: false,
      microphonePermissionDenied: false, state: 'CONNECTED',
    }))

    expect(html).toContain('В голосовом канале')
    expect(html).toContain('Voice')
    expect(html).not.toContain('voice-hint')
    expect(html).not.toContain('Вы можете открыть другой канал')
  })

  it('keeps the reconnection status without a secondary helper paragraph', async () => {
    const html = await renderToString(createSSRApp(VoiceDock, {
      channel: null, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
      deafenChanging: false, microphoneMuted: true, microphonePermissionDenied: false, state: 'RECONNECTING',
    }))

    expect(html).toContain('Восстанавливаем голосовое соединение')
    expect(html).not.toContain('voice-hint')
    expect(html).not.toContain('Ручной выход отменит ожидание.')
    expect(html).toContain('role="status"')
    expect(html).toContain('class="status-dot"')
    expect(html).not.toContain('Голос подключён · канал не отображается')
    expect(html).not.toContain('Канал сейчас не отображается.')
  })
})
