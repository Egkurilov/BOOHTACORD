import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  try { return readFileSync(new URL(relativePath, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('disconnected voice-room presentation', () => {
  it('uses a centered branded join state and explains when live participants appear', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const styles = source('../design/voice.css')

    expect(pane).toContain('class="voice-prejoin"')
    expect(pane).toContain('voice-prejoin-title')
    expect(pane).toContain('Подключитесь, чтобы увидеть участников комнаты и статусы микрофонов.')
    expect(pane).toContain('Подключиться к голосу')
    expect(styles).toContain('.voice-prejoin {')
    expect(styles).toContain('.voice-prejoin-card {')
  })
})
