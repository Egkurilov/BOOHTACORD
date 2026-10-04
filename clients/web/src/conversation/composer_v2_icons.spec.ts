import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const text = readFileSync(new URL('./TextConversation.vue', import.meta.url), 'utf8')
const direct = readFileSync(new URL('../direct_message/DirectMessageConversation.vue', import.meta.url), 'utf8')
const textAttachment = readFileSync(new URL('./TextMessageAttachmentPicker.vue', import.meta.url), 'utf8')
const directAttachment = readFileSync(new URL('../direct_message/DirectMessageAttachmentPicker.vue', import.meta.url), 'utf8')
const mention = readFileSync(new URL('./MentionPicker.vue', import.meta.url), 'utf8')
const css = readFileSync(new URL('../design/design_v2_contextual_overlays.css', import.meta.url), 'utf8')

describe('Design V2 live composer controls', () => {
  it('uses the handoff SVGs for attachment and mention while keeping their actions', () => {
    for (const attachment of [textAttachment, directAttachment]) {
      expect(attachment).toContain('<path d="M12 5v14M5 12h14"/>')
      expect(attachment).toContain('@click="openActions"')
    }
    expect(mention).toContain('<circle cx="12" cy="12" r="4"/>')
    expect(mention).toContain('M16 8v6a2 2 0 0 0 4 0v-2a8 8 0 1 0-3 6')
    expect(mention).toContain('@click="expanded = !expanded"')
    expect(css).toContain('.message-composer .mention-picker .mention-picker-trigger')
  })

  it('uses the handoff emoji and send outlines in both real composers', () => {
    for (const composer of [text, direct]) {
      expect(composer).toContain('<circle cx="12" cy="12" r="9"/>')
      expect(composer).toContain('M8 14a4 4 0 0 0 8 0M8 8h.01M16 8h.01')
      expect(composer).toContain('m22 2-7 20-4-9-9-4 20-7ZM22 2 11 13')
      expect(composer).toContain('@click="emojiOpen = !emojiOpen"')
      expect(composer).toContain('@submit.prevent="send"')
    }
  })

  it('routes the mobile plus menu to the existing attachment, mention, and emoji actions', () => {
    for (const attachment of [textAttachment, directAttachment]) {
      expect(attachment).toContain('useCompactComposerActions()')
      expect(attachment).toContain('Прикрепить файл')
      expect(attachment).toContain('Упомянуть')
      expect(attachment).toContain('Emoji')
      expect(attachment).toContain("emit('mention')")
      expect(attachment).toContain("emit('emoji')")
      expect(attachment).toContain('fileInput.value?.click()')
    }
    for (const composer of [text, direct]) {
      expect(composer).toContain('@mention="insertMobileMention"')
      expect(composer).toContain('@emoji="emojiOpen = true"')
    }
    expect(css).toContain('.message-composer .composer-mobile-actions')
    expect(css).toContain('.message-composer .mention-picker-trigger, .message-composer .emoji-trigger { display: none; }')
  })
})
