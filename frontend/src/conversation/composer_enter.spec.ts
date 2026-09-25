import { describe, expect, it, vi } from 'vitest'

import { submitOnComposerEnter } from './composer_enter'

type KeyEvent = Parameters<typeof submitOnComposerEnter>[0]

function keyEvent(overrides: Partial<KeyEvent> = {}): KeyEvent {
  return {
    key: 'Enter', shiftKey: false, ctrlKey: false, altKey: false, metaKey: false,
    isComposing: false, preventDefault: vi.fn(), ...overrides,
  }
}

describe('conversation composer Enter', () => {
  it('submits plain Enter and prevents a newline', () => {
    const event = keyEvent()
    const send = vi.fn()

    submitOnComposerEnter(event, send)

    expect(send).toHaveBeenCalledOnce()
    expect(event.preventDefault).toHaveBeenCalledOnce()
  })

  it.each([
    ['Shift+Enter', { shiftKey: true }],
    ['IME Enter', { isComposing: true }],
    ['Ctrl+Enter', { ctrlKey: true }],
    ['Alt+Enter', { altKey: true }],
    ['Meta+Enter', { metaKey: true }],
    ['another key', { key: 'a' }],
  ])('leaves %s to the textarea or existing shortcut', (_name, overrides) => {
    const event = keyEvent(overrides)
    const send = vi.fn()

    submitOnComposerEnter(event, send)

    expect(send).not.toHaveBeenCalled()
    expect(event.preventDefault).not.toHaveBeenCalled()
  })
})
