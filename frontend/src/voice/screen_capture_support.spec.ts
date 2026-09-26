import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { afterEach, describe, expect, it, vi } from 'vitest'

import VoiceDock from './VoiceDock.vue'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import { screenFailureMessage } from './screen_feedback'

afterEach(() => vi.unstubAllGlobals())

describe('browser screen capture availability', () => {
  it('explains unsupported Android Chrome before opening a nonexistent chooser', async () => {
    const androidChrome = 'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 Chrome/152.0 Mobile Safari/537.36'
    expect(screenCaptureSupported(androidChrome, { getDisplayMedia: vi.fn() })).toBe(false)
    expect(screenCaptureUnavailableMessage(androidChrome)).toContain('Android-приложении')
    expect(screenFailureMessage(Object.assign(new Error('getDisplayMedia not supported'), { name: 'DeviceUnsupportedError' }), androidChrome)).toContain('Android-приложении')

    vi.stubGlobal('navigator', { userAgent: androidChrome, mediaDevices: {} })
    const html = await renderToString(createSSRApp(VoiceDock, {
      channel: { id: 'voice', name: 'Voice', kind: 'VOICE', position: 0 }, activeSession: true,
      error: null, activationMode: 'VAD', deafened: false, deafenChanging: false,
      microphoneMuted: true, microphonePermissionDenied: false, state: 'CONNECTED',
    }))
    expect(html).toMatch(/aria-label="[^"]*Android-приложении[^"]*" disabled/)
  })

  it('allows browsers that expose display capture outside unsupported mobile Chrome', () => {
    expect(screenCaptureSupported('Mozilla/5.0 (Windows NT 10.0) Chrome/152.0', { getDisplayMedia: vi.fn() })).toBe(true)
    expect(screenCaptureSupported('Mozilla/5.0 (Windows NT 10.0) Chrome/152.0', undefined)).toBe(false)
  })
})
