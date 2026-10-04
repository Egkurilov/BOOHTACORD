import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { emojiCatalog, mergeEmojiNames, quickEmoji, searchEmoji, updateRecentEmoji } from './emoji_catalog'
import fullCatalog from './emoji_full_catalog.json'
import { insertEmojiAtRange } from './emoji_insert'
import EmojiPicker from './EmojiPicker.vue'

describe('shared composer emoji behavior', () => {
  it('inserts a modified emoji at the textarea selection without losing surrounding text', () => {
    expect(insertEmojiAtRange('Привет мир', 7, 10, '👍🏽')).toEqual({ text: 'Привет 👍🏽', caret: 11 })
    expect(insertEmojiAtRange('abc', 1, 1, '❤️')).toEqual({ text: 'a❤️bc', caret: 3 })
  })

  it('keeps the quick row and searches the broader named catalog', () => {
    expect(quickEmoji).toEqual(['😀', '👍', '🎮', '❤️', '🎉', '🤝'])
    expect(emojiCatalog.length).toBeGreaterThan(50)
    expect(searchEmoji('палец')).toContainEqual(expect.objectContaining({ emoji: '👍🏽' }))
  })

  it('loads the complete local Unicode catalog with Russian aliases', () => {
    expect(fullCatalog.length).toBeGreaterThan(3900)
    expect(searchEmoji('палец', mergeEmojiNames(fullCatalog))).toContainEqual(expect.objectContaining({ emoji: '👍🏽' }))
    expect(searchEmoji('avocado', fullCatalog)).toContainEqual(expect.objectContaining({ emoji: '🥑' }))
  })

  it('moves the selected emoji to recent without duplicates', () => {
    expect(updateRecentEmoji(['🎉', '😀'], '🎉')).toEqual(['🎉', '😀'])
    expect(updateRecentEmoji(['🎉', '😀'], '👍🏽')).toEqual(['👍🏽', '🎉', '😀'])
  })

  it('keeps the six quick choices behind the composer trigger', async () => {
    const html = await renderToString(createSSRApp(EmojiPicker, { disabled: false }))
    expect(html).toContain('Добавить emoji')
    expect(html).toContain('aria-expanded="false"')
  })
})
