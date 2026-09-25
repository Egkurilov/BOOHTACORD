import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageAttachmentPicker from '../direct_message/DirectMessageAttachmentPicker.vue'
import TextMessageAttachmentPicker from './TextMessageAttachmentPicker.vue'

describe('attachment composer keyboard trigger', () => {
  it.each([
    ['TEXT', TextMessageAttachmentPicker, { channelId: 'text-1', disabled: false, clearToken: 0 }],
    ['DM', DirectMessageAttachmentPicker, { directMessageId: 'dm-1', disabled: false, clearToken: 0 }],
  ])('%s exposes a visible focusable button while hiding the file input from Tab', async (_kind, component, props) => {
    const html = await renderToString(createSSRApp(component, props))
    expect(html).toMatch(/<input[^>]+type="file"[^>]+tabindex="-1"/)
    expect(html).toMatch(/<button[^>]+aria-label="Прикрепить файлы"/)
  })
})
