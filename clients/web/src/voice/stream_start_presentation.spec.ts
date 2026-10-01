import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

import VoiceDock from './VoiceDock.vue'
import VoiceParticipantVolumes from './VoiceParticipantVolumes.vue'
import { streamStartChime, streamStartNotice } from './stream_start_runtime'

describe('new screen presentation', () => {
  it('marks a remote participant live and offers a personal sound switch in the dock', async () => {
    streamStartChime.setEnabled(true)
    const participants = await renderToString(createSSRApp(VoiceParticipantVolumes, {
      error: null, participants: [{ id: 'alice', accountId: 'alice', name: 'Алиса', volume: 100, speaking: false, microphoneMuted: false }],
      screenStreams: [{ id: 'alice:screen', participantId: 'alice', participantName: 'Алиса', hasAudio: true }],
      selectedScreenStreamId: null, selfName: 'Оля', selfDeafened: false, selfMicrophoneMuted: false,
      selfMicrophoneUnavailable: false, selfSpeaking: false,
    }))
    const dock = await renderToString(createSSRApp(VoiceDock, {
      channel: null, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
      deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: false, state: 'CONNECTED',
    }))

    expect(participants).toContain('ЭФИР')
    expect(participants).toContain('Участник показывает экран')
    expect(dock).toContain('Звук начала трансляций включён')
    expect(dock).toContain('aria-pressed="true"')

    streamStartNotice.value = true
    streamStartChime.setEnabled(false)
    try {
      const silentDock = await renderToString(createSSRApp(VoiceDock, {
        channel: null, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
        deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: false, state: 'CONNECTED',
      }))
      expect(silentDock).toContain('Звук начала трансляций выключен')
      expect(silentDock).toContain('aria-pressed="false"')
      expect(silentDock).toContain('В канале началась демонстрация экрана')
    } finally {
      streamStartNotice.value = false
      streamStartChime.setEnabled(true)
    }
  })
})
