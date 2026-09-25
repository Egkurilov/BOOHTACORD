import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  try { return readFileSync(new URL(relativePath, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('voice-room visual status and screen presentation', () => {
  it('gives mute and speaking states visible, explicit icon labels', () => {
    const status = source('./VoiceParticipantStatus.vue')
    expect(status).toContain('Микрофон выключен')
    expect(status).toContain('Микрофон недоступен')
    expect(status).toContain('Говорит')
    expect(status).toContain('is-speaking')
    expect(status).toContain('is-muted')
    expect(status).toContain('aria-hidden="true"')
  })

  it('presents the local participant like the reference card, with speaking and self label', () => {
    const participants = source('./VoiceParticipantVolumes.vue')
    expect(participants).toContain(':speaking="selfSpeaking"')
    expect(participants).toContain('talking: selfSpeaking && !selfDeafened && !selfMicrophoneMuted && !selfMicrophoneUnavailable')
    expect(participants).toContain('`${name} · вы`')
    expect(participants).not.toContain('Это вы')
    expect(source('./connection_store.ts')).toContain('selfSpeaking: volume.selfSpeaking')
    expect(source('../workspace/WorkspaceMain.vue')).toContain(':self-speaking="voiceConnection.selfSpeaking"')
    expect(source('../conversation/ConversationPane.vue')).toContain(':self-speaking="selfSpeaking"')
  })

  it('shows the local deafened state distinctly from microphone mute', () => {
    const status = source('./VoiceParticipantStatus.vue')
    const cards = source('./VoiceParticipantVolumes.vue')
    expect(status).toContain('deafened')
    expect(status).toContain('Звук и микрофон выключены')
    expect(status).toContain('is-deafened')
    expect(cards).toContain(':deafened="selfDeafened"')
    expect(source('../workspace/WorkspaceMain.vue')).toContain(':self-deafened="voiceConnection.deafened"')
    expect(source('../conversation/ConversationPane.vue')).toContain(':self-deafened="selfDeafened"')
  })

  it('keeps voice connected and provides a direct return to the participant room', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const viewer = source('./ScreenViewer.vue')
    const members = source('../workspace/WorkspaceMembersPanel.vue')
    expect(pane).toContain('<template v-if="screenViewerCards.length || selectedScreenStreamId || screenViewerEnded">')
    expect(pane).toContain('<div v-if="!selectedScreenStreamId && !screenViewerEnded" class="room-wrap">')
    expect(pane).not.toContain('<VoiceParticipantStrip')
    expect(pane).toContain('voiceVolumeParticipants.length + 1')
    expect(pane).toContain('voiceRoomSummary(voiceVolumeParticipants.length + 1, screenViewerCards.length)')
    expect(pane).toContain('Все в сборе')
    expect(pane).toContain('подключитесь, чтобы увидеть участников')
    expect(viewer).toContain('participantAudioMessage(deafened)')
    expect(viewer).toContain('К участникам')
    expect(viewer).toContain('<video ref="video" v-show="selectedId"')
    expect(source('../workspace/WorkspaceMembersPanel.vue')).toContain('selfMicrophoneUnavailable')
    expect(members).toContain('Микрофон выключен')
    expect(members).toContain('Говорит')
  })

  it('distinguishes an unselected view from a selected but not joined voice room', () => {
    const panel = source('../workspace/WorkspaceMembersPanel.vue')
    expect(panel).toContain('selectedVoiceChannel')
    expect(panel).toContain('Подключитесь к каналу, чтобы увидеть его участников.')
    expect(panel).toContain('Участники гильдии')
    expect(source('../workspace/WorkspaceApp.vue')).toContain(':selected-voice-channel="selectedChannel?.kind === \'VOICE\' ? selectedChannel : null"')
  })

  it('exposes a fullscreen action and visible feedback on the stage', () => {
    const viewer = source('./ScreenViewer.vue')
    expect(viewer).toContain('Развернуть демонстрацию на весь экран')
    expect(viewer).toContain('Выйти из полноэкранного режима')
    expect(viewer).toContain('aria-live="polite"')
    expect(viewer).toContain('Развернуть на всю область')
    expect(viewer).toContain('Вернуть в окно канала')
    expect(viewer).toContain('update:expanded')
    expect(viewer).toContain('Escape')
    expect(source('../conversation/ConversationPane.vue')).toContain('voice-room--screen-expanded')
    expect(source('../conversation/ConversationPane.vue')).toContain('<Teleport to="body" :disabled="!screenExpanded">')
  })

  it('sizes video to the stage without cropping and preserves compact roster access', () => {
    const styles = source('../design/voice.css')
    const shell = source('../design/responsive_shell.css')
    expect(styles).toContain('object-fit: contain')
    expect(styles).toContain('.screen-stage:fullscreen')
    expect(styles).toContain('.voice-room--screen-expanded')
    expect(styles).toContain('position: fixed;')
    expect(styles).toContain('.voice-participant-strip')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-small) minmax(0, 1fr)')
    expect(shell).toContain('width: min(320px, calc(100% - 32px))')
  })
})
