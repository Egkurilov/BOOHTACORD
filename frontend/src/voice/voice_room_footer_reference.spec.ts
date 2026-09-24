import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

import VoiceRoomFooter from './VoiceRoomFooter.vue'

function source(path: string): string {
  try { return readFileSync(new URL(path, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('connected voice-room reference footer', () => {
  it('uses truthful connection copy and one contextual leave control', () => {
    const footer = source('./VoiceRoomFooter.vue')
    for (const text of ['Вы подключены к', 'Выйти из канала', 'Режим слушателя', 'Восстанавливаем', "state === 'LEAVING'", "emit('leave')"]) expect(footer).toContain(text)
    expect(footer).not.toContain('128 кбит/с')
  })

  it('renders listener state without claiming an unmeasured bitrate and disables leave while leaving', async () => {
    const listener = await renderToString(createSSRApp(VoiceRoomFooter, { channelName: 'Игровая', state: 'LISTENER', activationMode: 'VAD' }))
    const leaving = await renderToString(createSSRApp(VoiceRoomFooter, { channelName: 'Игровая', state: 'LEAVING', activationMode: 'PTT' }))

    expect(listener).toContain('Вы подключены к «Игровая»')
    expect(listener).toContain('Режим слушателя · микрофон не передаётся')
    expect(listener).not.toContain('128 кбит/с')
    expect(listener).not.toMatch(/<button[^>]*disabled/)
    expect(leaving).toContain('Завершаем голосовое подключение')
    expect(leaving).toMatch(/<button[^>]*disabled/)
  })

  it('wires the existing leave action and only displays the bar for the open connected room', () => {
    expect(source('../conversation/ConversationPane.vue')).toContain('<VoiceRoomFooter v-if="voiceIsActive && !selectedScreenStreamId && !screenViewerEnded"')
    expect(source('../workspace/WorkspaceMain.vue')).toContain('@leave="leaveVoice"')
    expect(source('../workspace/WorkspaceApp.vue')).toContain(':leave-voice="leaveVoice"')
    expect(source('../style.css')).toContain("@import './design/voice_room_footer.css';")
    expect(source('../design/voice_room_footer.css')).toContain('@media (min-width: 1024px)')
  })
})
