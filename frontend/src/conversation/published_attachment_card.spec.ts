import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageAttachments from '../direct_message/DirectMessageAttachments.vue'
import TextMessageAttachments from './TextMessageAttachments.vue'

const raster = { id: 'file ?#', originalName: 'очень-длинное-название-screenshot.png', sizeBytes: 1_250 }

describe('published attachment card', () => {
  it('renders a keyboard download card with a protected raster preview in TEXT', async () => {
    const html = await renderToString(createSSRApp(TextMessageAttachments, { channelId: 'channel/a', attachments: [raster] }))
    expect(html).toContain('class="attachment-card"')
    expect(html).toContain('href="/api/v1/channels/channel%2Fa/attachments/file%20%3F%23"')
    expect(html).toContain('download')
    expect(html).toContain('aria-label="Скачать очень-длинное-название-screenshot.png')
    expect(html).toContain('/api/v1/channels/channel%2Fa/attachments/file%20%3F%23/preview')
    expect(html).toContain('attachment-card__name')
    expect(html).toContain('КБ')
  })

  it('uses the private DM URL and an icon fallback for non-raster files', async () => {
    const file = { ...raster, originalName: 'report.pdf' }
    const html = await renderToString(createSSRApp(DirectMessageAttachments, { directMessageId: 'dm/a', attachments: [file] }))
    expect(html).toContain('class="attachment-card"')
    expect(html).toContain('href="/api/v1/direct-messages/dm%2Fa/attachments/file%20%3F%23"')
    expect(html).toContain('aria-label="Скачать report.pdf')
    expect(html).toContain('attachment-card__file-icon')
    expect(html).not.toContain('/preview')
  })
})
