import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import ConversationPane from './ConversationPane.vue'

describe('empty workspace navigation', () => {
  it('offers the navigation drawer trigger before a channel is selected', async () => {
    const html = await renderToString(createSSRApp(ConversationPane, {
      channel: null, directMessage: null, navOpen: false, membersOpen: false,
      showMembers: false, selfDisplayName: null, selfDeafened: false,
      voiceError: null, voiceIsActive: false, voiceState: 'DISCONNECTED',
      activationMode: 'VAD', voiceTransferRequired: false,
      screenError: null, screenViewerCards: [], screenViewerEnded: false,
      screenViewerError: null, screenDiagnostics: {}, screenProfile: null,
      screenState: 'IDLE', selectedScreenStreamId: null,
      selectedScreenAudioVolume: 100, selfMicrophoneMuted: false,
      selfMicrophoneUnavailable: false, selfSpeaking: false,
      voiceVolumeError: null, voiceVolumeParticipants: [],
    }))
    expect(html).toContain('Выберите канал')
    expect(html).toContain('aria-label="Открыть навигацию"')
    expect(html).toContain('aria-controls="nav-sidebar"')
  })
})
