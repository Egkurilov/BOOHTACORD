import { readFileSync } from 'node:fs'
import { createPinia, setActivePinia } from 'pinia'
import postcss from 'postcss'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import MessageItem from './MessageItem.vue'

const message = { id: 'message-1', channelId: 'channel-1', authorId: 'user-1', clientMessageId: 'client-1', body: 'Test', createdAt: '2026-09-25T10:00:00Z', revision: 1, deleted: false }
async function render(canEdit: boolean, canDelete: boolean, deleted = false): Promise<string> {
  const pinia = createPinia()
  setActivePinia(pinia)
  const app = createSSRApp(MessageItem, { message: { ...message, deleted }, canEdit, canDelete })
  app.use(pinia)
  return renderToString(app)
}

describe('C-22 message action toolbar', () => {
  it('offers an accessible disclosure while preserving action permissions', async () => {
    const editable = await render(true, false)
    expect(editable).toContain('aria-label="Действия с сообщением"')
    expect(editable).toContain('aria-expanded="false"')
    expect(editable).toContain('aria-controls="message-actions-message-1"')
    expect(editable).toContain('id="message-actions-message-1"')
    expect(editable).toContain('Ответить')
    expect(editable).toContain('Изменить')
    expect(editable).not.toContain('Удалить')
    expect(await render(false, true)).not.toContain('Изменить')
    expect(await render(false, true)).toContain('Удалить')
    expect(await render(true, true, true)).not.toContain('Действия с сообщением')
  })

  it('floats the actions without changing row height and exposes them on hover, focus and touch', () => {
    const root = postcss.parse(readFileSync(new URL('../design/conversation.css', import.meta.url), 'utf8'))
    const declarations = (selector: string, property: string) => {
      let value: string | undefined
      root.walkRules((rule) => { if (rule.selectors.includes(selector)) rule.walkDecls(property, (item) => { value = item.value }) })
      return value
    }
    expect(declarations('.message-row', 'position')).toBe('relative')
    expect(declarations('.message-actions', 'position')).toBeUndefined()
    expect(declarations('.message-row .message-actions', 'position')).toBe('absolute')
    const selectors: string[] = []
    root.walkRules((rule) => { selectors.push(...rule.selectors) })
    expect(selectors).toContain('.message-row:hover .message-actions .message-action-buttons')
    expect(selectors).toContain('.message-row:focus-within .message-actions .message-action-buttons')
    expect(selectors).toContain('.message-row .message-actions.is-open .message-action-buttons')
    const media: string[] = []
    root.walkAtRules('media', (rule) => { media.push(rule.params) })
    expect(media.some((params) => params.includes('hover: none') && params.includes('max-width: 600px'))).toBe(true)
  })

  it('leaves Escape for the surrounding drawer unless the disclosure is open', () => {
    const source = readFileSync(new URL('./MessageItem.vue', import.meta.url), 'utf8')
    const disclosure = readFileSync(new URL('./message_actions/disclosure.ts', import.meta.url), 'utf8')
    expect(source).toContain('@keydown.esc="closeActions"')
    expect(source).not.toContain('@keydown.esc.stop')
    expect(disclosure).toMatch(/function closeActions\(event: KeyboardEvent\)[\s\S]*?if \(!actionsOpen\.value\) return[\s\S]*?event\.stopPropagation\(\)/)
  })

  it('keeps the idle mobile disclosure out of the reference frame while allowing a touch reveal', () => {
    const css = readFileSync(new URL('../design/conversation.css', import.meta.url), 'utf8')
    const source = readFileSync(new URL('./MessageItem.vue', import.meta.url), 'utf8')
    const disclosure = readFileSync(new URL('./message_actions/disclosure.ts', import.meta.url), 'utf8')
    expect(css).toMatch(/\.message-row \.message-actions-toggle \{[^}]*opacity: 0;[^}]*pointer-events: none;/)
    expect(css).toContain('.message-row .message-actions.is-open .message-actions-toggle')
    expect(source).toContain('@pointerdown="onRowPointerDown"')
    expect(source).toContain('@focusout="onRowFocusOut"')
    expect(disclosure).toMatch(/function onRowPointerDown\(event: PointerEvent\)[\s\S]*?event\.pointerType !== 'touch'[\s\S]*?closest\('[^']*button[^']*a[^']*'\)[\s\S]*?actionsOpen\.value = true/)
  })
})
