import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import SensitivityControl from './SensitivityControl.vue'
import GainControl from './GainControl.vue'
describe('accessible microphone controls', () => {
  it('provides numeric dBFS threshold and a pre-gain meter; PTT disables it', async () => {
    const html = await renderToString(createSSRApp(SensitivityControl, { vad: false }))
    expect(html).toContain('microphone-vad-threshold')
    expect(html).toContain('aria-valuetext="-50 dBFS"')
    expect(html).toContain('role="meter"')
    expect(html).toContain('disabled')
    expect(html).toContain('В режиме PTT порог не используется.')
  })
  it('explains AGC and disables manual input gain', async () => {
    const html = await renderToString(createSSRApp(GainControl, { agc: true }))
    expect(html).toContain('microphone-input-gain')
    expect(html).toContain('max="200"')
    expect(html).toContain('disabled')
    expect(html).toContain('Управляется автоматически')
  })
})
