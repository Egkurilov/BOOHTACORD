import { describe, expect, it } from 'vitest'
import { participantAudioMessage, screenAudioMessage } from './screen_audio_copy'

describe('screen audio copy', () => {
  it('separates track presence from audible game sound', () => {
    expect(screenAudioMessage({ isLocal: false, hasAudio: true, adjustable: true, deafened: false })).toBe('')
    expect(screenAudioMessage({ isLocal: false, hasAudio: true, adjustable: false, deafened: false })).toBe('Аудиодорожка есть; личная настройка громкости недоступна.')
    expect(screenAudioMessage({ isLocal: false, hasAudio: false, adjustable: false, deafened: false })).toBe('У демонстрации нет аудиодорожки.')
  })

  it('states local preview and deafen without promising playback', () => {
    expect(screenAudioMessage({ isLocal: true, hasAudio: true, adjustable: false, deafened: false })).toBe('Предпросмотр собственного экрана без звука.')
    expect(screenAudioMessage({ isLocal: false, hasAudio: true, adjustable: true, deafened: true })).toBe('Удалённый звук выключен; аудиодорожка сейчас не воспроизводится.')
    expect(participantAudioMessage(true)).toBe('Удалённый звук выключен.')
    expect(participantAudioMessage(false)).toBe('Звук участников управляется отдельно от демонстрации.')
  })
})
