import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import ProfileSettings from '../identity/ProfileSettings.vue'
import AudioSettings from '../voice/AudioSettings.vue'

describe('settings panel focus targets', () => {
  it('exposes a programmatically focusable profile heading', async () => {
    const app = createSSRApp(ProfileSettings, { profile: null, loading: false, loadError: null })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toMatch(/<h1[^>]*id="profile-settings-title"[^>]*tabindex="-1"/)
  })

  it('exposes a programmatically focusable audio region', async () => {
    const processing = { autoGainControl: true, echoCancellation: true, noiseSuppression: true }
    const unavailable = { requested: true, reported: 'UNAVAILABLE' as const }
    const html = await renderToString(createSSRApp(AudioSettings, {
      activationError: null, activationMode: 'VAD', processingDiagnostics: {
        autoGainControl: unavailable, echoCancellation: unavailable, noiseSuppression: unavailable,
      }, devices: { inputs: [], outputs: [] }, error: null, pttKey: null, processing, state: 'IDLE',
    }))
    expect(html).toMatch(/<section[^>]*class="audio-settings"[^>]*tabindex="-1"/)
  })
})
