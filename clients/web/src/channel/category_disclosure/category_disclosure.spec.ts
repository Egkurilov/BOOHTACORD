import { createSSRApp, nextTick, ref } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { createPinia } from 'pinia'
import { describe, expect, it } from 'vitest'

import ChannelNavigation from '../ChannelNavigation.vue'
import { useCategoryDisclosure } from './use_category_disclosure'

describe('category disclosure', () => {
  it('opens every category initially and toggles only the selected category', () => {
    const disclosure = useCategoryDisclosure('account-a', 'https://guild.example', null)
    expect(disclosure.isOpen('chat')).toBe(true)
    expect(disclosure.isOpen('voice')).toBe(true)
    disclosure.toggle('chat')
    expect(disclosure.isOpen('chat')).toBe(false)
    expect(disclosure.isOpen('voice')).toBe(true)
    disclosure.toggle('chat')
    expect(disclosure.isOpen('chat')).toBe(true)
  })

  it('restores collapsed state when the same account returns', () => {
    const values = new Map<string, string>()
    const storage = { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => values.set(key, value) }
    useCategoryDisclosure('account-a', 'https://guild.example', storage).toggle('chat')
    expect(useCategoryDisclosure('account-a', 'https://guild.example', storage).isOpen('chat')).toBe(false)
  })

  it('switches preference scope if the mounted navigation changes account', async () => {
    const values = new Map<string, string>()
    const storage = { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => { values.set(key, value) } }
    const account = ref('account-a')
    const disclosure = useCategoryDisclosure(() => account.value, 'https://guild.example', storage)
    disclosure.toggleFavorite('channel-a')
    account.value = 'account-b'
    await nextTick()
    expect(disclosure.isFavorite('channel-a')).toBe(false)
    account.value = 'account-a'
    await nextTick()
    expect(disclosure.isFavorite('channel-a')).toBe(true)
  })

  it('renders an expanded heading control while keeping channel selection separate', async () => {
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      accountId: 'account-a',
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
