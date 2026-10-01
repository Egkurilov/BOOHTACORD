import { ref, shallowRef } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { installVoiceConnectionLifecycle } from './connection_lifecycle'
import type { VoiceConnectionState } from './connection_store'
import type { ScreenProfile } from './livekit_gateway'
import type { ScreenShareState } from './screen_controls'
import { unknownScreenDiagnostics } from './screen_diagnostics'
import type { ActiveVoiceSession } from './voice_session'

describe('voice connection lifecycle', () => {
  it('clears local controls when the media room disconnects permanently', () => {
    let observer: { disconnected(): void } | undefined
    const session = { setConnectionObserver: vi.fn((value) => { observer = value }) }
    const active = shallowRef<ActiveVoiceSession | null>({ channelId: 'channel-1', leaseId: 'lease-1', microphone: 'PUBLISHED', room: {} as never, screenProfile: null })
    const state = ref<VoiceConnectionState>('CONNECTED')
    const error = ref<string | null>(null)
    const microphoneMuted = ref(true)
    const microphonePermissionDenied = ref(true)
    const deafened = ref(true)
    const screenDiagnostics = ref(unknownScreenDiagnostics())
    const screenProfile = ref<ScreenProfile | null>('P1080_60')
    const screenState = ref<ScreenShareState>('SHARING')
    const screenViewer = { stop: vi.fn() }
    const volume = { stop: vi.fn() }
    const refresh = vi.fn()

    installVoiceConnectionLifecycle(session as never, active, state, error, microphoneMuted, microphonePermissionDenied, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refresh)
    observer?.disconnected()

    expect(screenViewer.stop).toHaveBeenCalledOnce()
    expect(volume.stop).toHaveBeenCalledOnce()
    expect(active.value).toBeNull()
    expect(state.value).toBe('ERROR')
    expect(error.value).toMatch('не восстановлено')
  })
})
