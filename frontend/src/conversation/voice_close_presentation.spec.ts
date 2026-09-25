import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import ConversationPane from './ConversationPane.vue'

describe('VOICE closed-admission presentation', () => {
  it('shows the server reason and safe exit while a participant still has an active lease', async () => {
    const html = await renderToString(createSSRApp(ConversationPane, {
      channel: { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 0, admissionClosed: true },
      directMessage: null, navOpen: false, membersOpen: false, showMembers: false, selfDisplayName: 'Участник', selfDeafened: false,
      voiceError: 'Голосовой канал закрыт администратором.', voiceIsActive: true, voiceState: 'CONNECTED',
      activationMode: 'VAD', voiceTransferRequired: false, screenError: null, screenViewerCards: [],
      screenViewerEnded: false, screenViewerError: null, screenDiagnostics: {}, screenProfile: null,
      screenState: 'IDLE', selectedScreenStreamId: null, selectedScreenAudioVolume: 100,
      selfMicrophoneMuted: false, selfMicrophoneUnavailable: false, selfSpeaking: false,
      voiceVolumeError: null, voiceVolumeParticipants: [],
    }))
    expect(html).toContain('Отзыв media-доступа ещё подтверждается')
    expect(html).toContain('Голосовой канал закрыт администратором')
    expect(html).toContain('Выйти из голосового канала')
    expect(html).not.toContain('Подключиться')
  })
})
