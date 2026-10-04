import { createSSRApp } from 'vue'
import { renderToString } from '@vue/server-renderer'
import { describe, expect, it } from 'vitest'

import VoiceDock from './VoiceDock.vue'

const props = {
  channel: { id: 'voice-1', kind: 'VOICE', name: 'Игровая' },
  activeSession: true,
  error: null,
  activationMode: 'VAD' as const,
  deafened: false,
  deafenChanging: false,
  microphoneMuted: false,
  microphonePermissionDenied: false,
  state: 'CONNECTED' as const,
}

describe('voice connection quality presentation', () => {
  it('shows the local LiveKit quality and measured ping in the dock', async () => {
    const html = await renderToString(createSSRApp(VoiceDock, {
      ...props,
      connectionQuality: 'EXCELLENT',
      pingMs: 42,
    }))

    expect(html).toMatch(/class="[^"]*voice-quality[^"]*voice-quality--excellent|class="[^"]*voice-quality--excellent[^"]*voice-quality/)
    expect(html).toContain('Качество соединения: Отличное · ping 42 мс')
    expect(html).toContain('42 мс')
  })

  it('keeps missing ping explicit instead of reporting zero', async () => {
    const html = await renderToString(createSSRApp(VoiceDock, {
      ...props,
      connectionQuality: 'UNKNOWN',
      pingMs: null,
    }))

    expect(html).toContain('Качество соединения: Нет данных · ping —')
    expect(html).toContain('voice-quality--unmeasured')
    expect(html).not.toContain('0 мс')
  })
})
