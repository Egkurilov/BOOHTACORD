import { effectScope, ref } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { unknownScreenDiagnostics } from './screen_diagnostics'
import { installScreenSenderReporting } from './screen_sender_reporting'
import type { ScreenShareState } from './screen_controls'

afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals() })

describe('screen sender reporting', () => {
  it('reports an active Android sender while its page is hidden and stops with the share', async () => {
    vi.useFakeTimers()
    vi.stubGlobal('document', { visibilityState: 'hidden' })
    const request = vi.fn(async () => new Response(null, { status: 204 }))
    vi.stubGlobal('fetch', request)
    const state = ref<ScreenShareState>('IDLE')
    const diagnostics = ref(unknownScreenDiagnostics())
    const refresh = vi.fn(async () => { diagnostics.value = {
      source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD',
      measured: { width: 1080, height: 2400, framesPerSecond: 18 },
    } })
    const scope = effectScope()
    scope.run(() => installScreenSenderReporting(state, diagnostics, refresh, 'android_web'))

    state.value = 'SHARING'
    await vi.advanceTimersByTimeAsync(1000)
    expect(refresh).toHaveBeenCalledTimes(2)
    await vi.advanceTimersByTimeAsync(4000)
    expect(refresh).toHaveBeenCalledTimes(6)
    expect(request).toHaveBeenCalledOnce()
    const [, init] = request.mock.calls[0] as unknown as [string, RequestInit]
    expect(JSON.parse(String(init.body))).toMatchObject({ direction: 'sender', platform: 'android_web', encoded_fps: 18 })

    state.value = 'IDLE'
    await vi.advanceTimersByTimeAsync(10000)
    expect(request).toHaveBeenCalledOnce()
    scope.stop()
  })
})
