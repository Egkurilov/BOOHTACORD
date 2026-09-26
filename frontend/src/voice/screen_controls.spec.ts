import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { createScreenControls, type ScreenShareState } from './screen_controls'
import { unknownScreenDiagnostics } from './screen_diagnostics'

describe('screen controls', () => {
  it('does not overlap periodic screen measurements', async () => {
    let finishRead: ((value: ReturnType<typeof unknownScreenDiagnostics>) => void) | undefined
    const session = {
      readScreenDiagnostics: vi.fn(() => new Promise<ReturnType<typeof unknownScreenDiagnostics>>((resolve) => { finishRead = resolve })),
      startScreen: vi.fn(), stopScreen: vi.fn(),
    }
    const controls = createScreenControls(session, ref({}), ref(null), ref(null), ref<ScreenShareState>('SHARING'), ref(unknownScreenDiagnostics()))

    const first = controls.refreshScreenDiagnostics()
    await controls.refreshScreenDiagnostics()
    expect(session.readScreenDiagnostics).toHaveBeenCalledOnce()
    finishRead?.(unknownScreenDiagnostics())
    await first
  })

  it('keeps screen sharing active while warning that the browser supplied no audio track', async () => {
    const screenDiagnostics = ref(unknownScreenDiagnostics())
    const screenError = ref<string | null>(null)
    const screenProfile = ref(null)
    const screenState = ref<'IDLE' | 'STARTING' | 'SHARING' | 'STOPPING' | 'ERROR'>('IDLE')
    const session = {
      readScreenDiagnostics: vi.fn(),
      startScreen: vi.fn().mockResolvedValue({ audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' }),
      stopScreen: vi.fn(),
    }
    const controls = createScreenControls(session, ref({}), screenError, screenProfile, screenState, screenDiagnostics)

    await controls.startScreen('P1080_60')

    expect(screenDiagnostics.value.audioTrack).toBe('ABSENT')
    expect(screenError.value).toContain('без аудиодорожки')
    expect(screenState.value).toBe('SHARING')
  })

  it('reports a finished source after an explicit measurement refresh', async () => {
    const screenDiagnostics = ref(unknownScreenDiagnostics())
    const screenError = ref<string | null>(null)
    const screenProfile = ref(null)
    const screenState = ref<'IDLE' | 'STARTING' | 'SHARING' | 'STOPPING' | 'ERROR'>('IDLE')
    const session = {
      readScreenDiagnostics: vi.fn().mockResolvedValue({ audioTrack: 'PRESENT', connectionQuality: 'LOST', measured: null, source: 'ENDED' }),
      startScreen: vi.fn().mockResolvedValue({ audioTrack: 'PRESENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' }),
      stopScreen: vi.fn(),
    }
    const controls = createScreenControls(session, ref({}), screenError, screenProfile, screenState, screenDiagnostics)

    await controls.startScreen('P720_30')
    await controls.refreshScreenDiagnostics()

    expect(screenDiagnostics.value.source).toBe('ENDED')
    expect(screenError.value).toContain('Источник демонстрации завершён')
    expect(screenState.value).toBe('IDLE')
    expect(screenProfile.value).toBeNull()
    expect(session.stopScreen).toHaveBeenCalledOnce()
  })
})
