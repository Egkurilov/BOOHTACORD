import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { formatScreenVideoQuality } from './screen_video_quality'

function source(relativePath: string): string {
  return readFileSync(new URL(relativePath, import.meta.url), 'utf8')
}

describe('screen viewer reference composition', () => {
  it('shows stream identity, truthful target/actual quality, canvas, and a return-to-room action', () => {
    const viewer = source('./ScreenViewer.vue')

    expect(viewer).toContain('screen-stage-label')
    expect(viewer).toContain('screen-publisher-name')
    expect(viewer).toContain('stream-target')
    expect(viewer).toContain('stream-actual')
    expect(source('./screen_playback_quality.ts')).toContain('Определяем качество…')
    expect(viewer).toContain('participantAudioMessage(deafened)')
    expect(viewer).toContain('Невыбранные демонстрации не воспроизводятся')
    expect(viewer).toContain('К участникам')
    expect(viewer).toContain('stream-voice-return')
  })

  it('renders each available publisher as a labelled metadata choice, not a video thumbnail', () => {
    const viewer = source('./ScreenViewer.vue')
    const styles = source('../design/voice_viewer_reference.css')

    expect(viewer).toContain('screen-cards stream-rail')
    expect(viewer).toContain('stream-avatar')
    expect(viewer).toContain('participantName')
    expect(viewer).toContain('aria-pressed')
    expect(viewer).toContain('hasAudio')
    expect(viewer).toContain("stream.id === selectedId ? 'Вы смотрите' : 'Нажмите, чтобы смотреть'")
    expect(viewer).toContain("stream.hasAudio ? 'Звуковая дорожка есть' : 'Звуковой дорожки нет'")
    expect(viewer).toContain('screen-player')
    expect(styles).toContain('.stream-voice-return')
    expect(styles).toContain('min-width: 152px')
    expect(styles).toContain('max-width: 200px')
  })

  it('shows the C-32 overflow affordance only while more rail content remains', () => {
    const viewer = source('./ScreenViewer.vue')
    const styles = source('../design/voice_viewer_reference.css')
    const tokens = source('../design/tokens.css')

    expect(viewer).toContain('observeHorizontalOverflow')
    expect(viewer).toContain('railHasOverflow')
    expect(viewer).toContain(':aria-description=')
    expect(styles).toContain('.screen-cards.stream-rail.has-overflow::after')
    expect(styles).toContain('var(--gc-surface) 70%')
    expect(styles).not.toContain('--gc-surface-base')
    expect(tokens).toContain('--gc-layout-row-voice-member: 24px')
  })

  it('labels the owner screen preview and keeps its video muted', () => {
    const viewer = source('./ScreenViewer.vue')

    expect(viewer).toContain("stream.isLocal ? 'Ваш экран' : (stream.participantName || 'Участник')")
    expect(viewer).toContain(':muted="selectedStream?.isLocal ?? false"')
    expect(source('./screen_audio_copy.ts')).toContain('Предпросмотр собственного экрана без звука')
    expect(viewer).toContain('ScreenViewerAudioControl v-if="selectedStream.hasAudio && !selectedStream.isLocal"')
    expect(source('./ScreenViewerAudioControl.vue')).toContain('v-if="adjustable"')
    expect(source('../conversation/ConversationPane.vue')).toContain(':deafened="selfDeafened"')
    expect(viewer).toContain('data-testid="stream-rail"')
    expect(viewer).toContain('data-testid="stream-select"')
  })

  it('names the selected stream in the stable voice-room header', () => {
    const pane = source('../conversation/ConversationPane.vue')

    expect(pane).toContain('selectedScreenName ?')
    expect(pane).toContain('Демонстрация ${selectedScreenName}')
  })

  it('shows dimensions only after real video metadata arrives', () => {
    expect(formatScreenVideoQuality({ videoWidth: 1920, videoHeight: 1080 })).toBe('1920 × 1080 · FPS не определена')
    expect(formatScreenVideoQuality({ videoWidth: 1920, videoHeight: 1080 }, 1)).toBe('1920 × 1080 · 1 FPS у зрителя')
    expect(formatScreenVideoQuality({ videoWidth: 1920, videoHeight: 1080 }, 0)).toBe('1920 × 1080 · 0 FPS у зрителя')
    expect(formatScreenVideoQuality({ videoWidth: 0, videoHeight: 0 })).toBe('Определяем качество…')
    expect(source('./ScreenViewer.vue')).toContain('@loadedmetadata="refreshVideoQuality"')
    expect(source('./ScreenViewer.vue')).toContain('@resize="refreshVideoQuality"')
  })

  it('keeps an ended selected stream visible until the user returns or selects another', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const viewer = source('./ScreenViewer.vue')

    expect(pane).toContain('screenViewerEnded')
    expect(pane).toContain('screenViewerCards.length || selectedScreenStreamId || screenViewerEnded')
    expect(pane).toContain(':ended="screenViewerEnded"')
    expect(pane).toContain('selectedScreenStreamId !== null || screenViewerEnded')
    expect(viewer).toContain('Демонстрация завершена.')
  })

  it('shows a waiting-frame state until the selected publisher produces decoded video', () => {
    const viewer = source('./ScreenViewer.vue')

    expect(viewer).toContain('videoReady')
    expect(viewer).toContain('Получаем первый кадр демонстрации…')
    expect(viewer).toContain('@loadeddata="markVideoReady"')
    expect(viewer).toContain('@emptied="resetVideoFrame"')
  })
  it('stacks viewer controls before the toolbar can overflow at zoomed and narrow widths', () => {
    const styles = source('../design/voice_viewer_reference.css')

    expect(styles).toContain('@media (max-width: 1100px)')
    expect(styles).toContain('.stream-quality-row .volume-control, .stream-audio-status')
    expect(styles).toContain('.stream-quality-row, .stream-quality, .stream-voice-return { flex-wrap: wrap; }')
    expect(styles).toContain('.stream-voice-return button:first-of-type { margin-left: 0; }')
  })
})
