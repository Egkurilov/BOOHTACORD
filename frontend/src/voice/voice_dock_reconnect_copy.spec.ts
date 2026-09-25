import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import VoiceDock from './VoiceDock.vue'

describe('VOICE dock reconnect copy', () => {
  it('announces reconnection before missing-channel copy while the session is still active', async () => {
    const html = await renderToString(createSSRApp(VoiceDock, {
      channel: null, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
      deafenChanging: false, microphoneMuted: true, microphonePermissionDenied: false, state: 'RECONNECTING',
    }))

    expect(html).toContain('Восстанавливаем голосовое соединение')
    expect(html).toContain('Ручной выход отменит ожидание.')
    expect(html).toContain('role="status"')
    expect(html).toContain('class="status-dot"')
    expect(html).not.toContain('Голос подключён · канал не отображается')
    expect(html).not.toContain('Канал сейчас не отображается.')
  })
})
