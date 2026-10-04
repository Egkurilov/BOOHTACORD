import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageConversation from '../direct_message/DirectMessageConversation.vue'
import TextConversation from './TextConversation.vue'

describe('TEXT and DM composer guidance', () => {
  it.each([
    ['TEXT', TextConversation, { accountId: 'self', active: true, channelId: 'channel-a', channelName: 'Общий', navOpen: false, membersOpen: false, showMembers: false }, 'message-body', 'text-composer-help'],
    ['DM', DirectMessageConversation, { accountId: 'self', active: true, directMessageId: 'dm-a', otherParticipantId: 'peer', otherParticipantDisplayName: 'Лера', navOpen: false }, 'direct-message-body', 'direct-composer-help'],
  ])('%s keeps the upload trigger before mentions and describes a one-row textarea with visible shortcuts', async (_kind, component, props, textareaId, helpId) => {
    const app = createSSRApp(component, props)
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain(`id="${helpId}"`)
    expect(html).toContain('Enter — отправить · Shift + Enter — новая строка')
    expect(html).toContain('Файлы до 25 МБ')
    expect(html).toMatch(new RegExp(`<textarea[^>]*id="${textareaId}"[^>]*aria-describedby="${helpId}"`))
    expect(html).toMatch(/<textarea[^>]*rows="1"/)
    expect(html.indexOf('aria-label="Прикрепить файлы"')).toBeLessThan(html.indexOf('aria-label="Выбрать упоминание"'))
  })
})
