import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminMediaSampleCard from './AdminMediaSampleCard.vue'

describe('anonymous administrator media sample', () => {
  it('shows real receive/decode/display stages without an account identity', async () => {
    const html = await renderToString(createSSRApp(AdminMediaSampleCard, { sample: {
      platform: 'ios_web', direction: 'receiver', state: 'playing', sampled_at_utc: '2026-10-04T12:00:00Z',
      frame_width: 540, frame_height: 1170, decoded_fps: 30, presented_fps: 26,
    } }))
    for (const label of ['iPhone/iPad · браузер', 'Приём', 'Декодирование', 'Показ', '540 × 1170', '30 FPS', '26 FPS']) {
      expect(html).toContain(label)
    }
    expect(html).not.toContain('account_id')
  })
})
