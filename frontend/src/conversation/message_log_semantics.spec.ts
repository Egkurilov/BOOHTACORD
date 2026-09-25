import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageHistoryList from '../direct_message/DirectMessageHistoryList.vue'
import TextHistoryList from './TextHistoryList.vue'

describe('message history screen-reader semantics', () => {
  it('keeps TEXT and DM history navigable as logs with a separate limited live status', async () => {
    const textApp = createSSRApp(TextHistoryList, { channelId: 'text-1', session: null })
    textApp.use(createPinia())
    const text = await renderToString(textApp)
    const dmApp = createSSRApp(DirectMessageHistoryList, {
      directMessageId: 'dm-1', session: null, otherParticipantId: 'other', otherParticipantDisplayName: 'Мика',
    })
    dmApp.use(createPinia())
    const dm = await renderToString(dmApp)

    for (const html of [text, dm]) {
      expect(html).toContain('role="log"')
      expect(html).toContain('aria-live="off"')
      expect(html).toContain('role="status"')
      expect(html).toContain('aria-atomic="true"')
    }
  })
})
