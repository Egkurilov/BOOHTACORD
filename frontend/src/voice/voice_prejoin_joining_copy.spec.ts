import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import VoicePrejoin from './VoicePrejoin.vue'

async function render(state: 'IDLE' | 'JOINING'): Promise<string> {
  return renderToString(createSSRApp(VoicePrejoin, {
    channelId: 'voice-fixture', voiceError: null, voiceState: state, voiceTransferRequired: false,
  }))
}

describe('voice prejoin joining copy', () => {
  it('announces connection in progress without repeating the idle invitation', async () => {
    const html = await render('JOINING')
    expect(html).toContain('Подключаемся к голосовой комнате')
    expect(html).toContain('Соединение устанавливается. Участники появятся после подключения.')
    expect(html).toContain('aria-live="polite"')
    expect(html).not.toContain('Вы не подключены')
    expect(html).not.toContain('Подключитесь, чтобы увидеть участников')
  })

  it('keeps the truthful join invitation while idle', async () => {
    const html = await render('IDLE')
    expect(html).toContain('Вы не подключены')
    expect(html).toContain('Подключитесь, чтобы увидеть участников')
    expect(html).not.toContain('Соединение устанавливается')
  })
})
