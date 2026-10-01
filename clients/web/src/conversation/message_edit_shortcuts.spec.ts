import { readFileSync } from 'node:fs'
import { describe, expect, it, vi } from 'vitest'

import { useMessageEditController } from './message_edit_controller'
import { handleMessageEditKeydown } from './message_edit_shortcuts'

function key(value: string, overrides: Partial<{ ctrlKey: boolean; metaKey: boolean; altKey: boolean; isComposing: boolean; keyCode: number }> = {}) {
  return { key: value, ctrlKey: false, metaKey: false, altKey: false, isComposing: false, keyCode: 0,
    preventDefault: vi.fn(), stopPropagation: vi.fn(), ...overrides }
}

describe('C-22 inline edit shortcuts', () => {
  it('cancels with Escape without mutating the original message', () => {
    const original = { body: 'Исходный текст', mentionUserIds: [], revision: 1 }
    const save = vi.fn()
    const editor = useMessageEditController({ save, refresh: vi.fn() })
    editor.begin(original)
    editor.body.value = 'Несохранённый черновик'
    const event = key('Escape')
    handleMessageEditKeydown(event, () => editor.cancel(), () => { void editor.submit() })
    expect(editor.editing.value).toBe(false)
    expect(original.body).toBe('Исходный текст')
    expect(save).not.toHaveBeenCalled()
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(event.stopPropagation).toHaveBeenCalledOnce()
  })

  it.each([['Ctrl', { ctrlKey: true }], ['Cmd', { metaKey: true }]])('saves with %s+Enter', async (_label, modifier) => {
    const save = vi.fn().mockResolvedValue({ kind: 'saved' })
    const editor = useMessageEditController({ save, refresh: vi.fn() })
    editor.begin({ body: 'Исходный текст', mentionUserIds: [], revision: 1 })
    editor.body.value = 'Изменённый текст'
    const event = key('Enter', modifier)
    let pending: Promise<void> | undefined
    handleMessageEditKeydown(event, () => editor.cancel(), () => { pending = editor.submit() })
    await pending
    expect(save).toHaveBeenCalledExactlyOnceWith('Изменённый текст', [], 1)
    expect(editor.editing.value).toBe(false)
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(event.stopPropagation).toHaveBeenCalledOnce()
  })

  it('leaves composition and unmodified Enter to the textarea', () => {
    const cancel = vi.fn()
    const save = vi.fn()
    for (const event of [key('Enter', { ctrlKey: true, isComposing: true }), key('Enter', { metaKey: true, keyCode: 229 }), key('Escape', { isComposing: true }), key('Enter')]) {
      handleMessageEditKeydown(event, cancel, save)
      expect(event.preventDefault).not.toHaveBeenCalled()
      expect(event.stopPropagation).not.toHaveBeenCalled()
    }
    expect(cancel).not.toHaveBeenCalled()
    expect(save).not.toHaveBeenCalled()
  })

  it('wires textarea keydown without changing the toolbar Escape handler', () => {
    const source = readFileSync(new URL('./MessageItem.vue', import.meta.url), 'utf8')
    expect(source).toContain('@keydown="onEditKeydown"')
    expect(source).toContain('@keydown.esc="closeActions"')
    expect(source).toContain('tabindex="-1"')
    expect(source).toContain('row.value?.focus()')
  })
})
