import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import VoiceDock from './VoiceDock.vue'

describe('VOICE dock after channel closure', () => {
  it('keeps a manual exit available while local media is still active but topology has finalized', async () => {
    const html = await renderToString(createSSRApp(VoiceDock, {
      channel: null, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
      deafenChanging: false, microphoneMuted: true, microphonePermissionDenied: false, state: 'CONNECTED',
    }))
    expect(html).toContain('Выйти из голосового канала')
    expect(html).toContain('Голос подключён · канал не отображается')
    expect(html).not.toContain('Голос не подключён')
  })

  it('shows the addressed server revocation reason after media teardown', async () => {
    const html = await renderToString(createSSRApp(VoiceDock, {
      channel: null, activeSession: false, error: 'Голосовой канал закрыт администратором.', activationMode: 'VAD',
      deafened: false, deafenChanging: false, microphoneMuted: true, microphonePermissionDenied: false, state: 'IDLE',
    }))
    expect(html).toContain('Голосовой канал закрыт администратором.')
  })
})
