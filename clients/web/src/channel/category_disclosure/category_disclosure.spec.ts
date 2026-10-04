import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { createPinia } from 'pinia'
import { describe, expect, it } from 'vitest'

import ChannelNavigation from '../ChannelNavigation.vue'
import { useCategoryDisclosure } from './use_category_disclosure'

describe('category disclosure', () => {
  it('opens every category initially and toggles only the selected category', () => {
    const disclosure = useCategoryDisclosure()
    expect(disclosure.isOpen('chat')).toBe(true)
    expect(disclosure.isOpen('voice')).toBe(true)
    disclosure.toggle('chat')
    expect(disclosure.isOpen('chat')).toBe(false)
    expect(disclosure.isOpen('voice')).toBe(true)
    disclosure.toggle('chat')
    expect(disclosure.isOpen('chat')).toBe(true)
  })

  it('renders an expanded heading control while keeping channel selection separate', async () => {
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      topology: { revision: 1, categories: [{ id: 'chat', name: 'Общение', position: 0, channels: [
        { id: 'general', name: 'Общий', kind: 'TEXT', position: 0, admissionClosed: false },
      ] }] }, voicePresence: null,
    }).use(createPinia()))
    expect(html).toContain('aria-label="Свернуть раздел Общение"')
    expect(html).toContain('aria-expanded="true"')
    expect(html).toContain('class="channel-button"')
    expect(html).toContain('m8 10 4 4 4-4')
  })
})
