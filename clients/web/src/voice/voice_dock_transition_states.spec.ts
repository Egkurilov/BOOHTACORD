import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import VoiceDock from './VoiceDock.vue'
import type { VoiceConnectionState } from './connection_store'

async function renderDock(state: VoiceConnectionState, activeSession = false): Promise<string> {
  return renderToString(createSSRApp(VoiceDock, {
    channel: null, activeSession, error: null, activationMode: 'VAD', deafened: false,
    deafenChanging: false, microphoneMuted: true, microphonePermissionDenied: false, state,
  }))
}

describe('VOICE dock transition states', () => {
  it('announces joining instead of presenting a pending lease as disconnected', async () => {
    const html = await renderDock('JOINING')

    expect(html).toContain('Подключаемся к голосовому каналу')
    expect(html).not.toContain('Голос не подключён')
    expect(html).not.toContain('class="connected status-dot"')
  })

  it('announces leaving without claiming a live connection', async () => {
    const html = await renderDock('LEAVING', true)

    expect(html).toContain('Завершаем голосовое подключение')
    expect(html).not.toContain('Голос подключён · канал не отображается')
    expect(html).not.toContain('class="connected status-dot"')
  })
})
