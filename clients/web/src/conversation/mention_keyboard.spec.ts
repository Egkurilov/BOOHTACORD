import { describe, expect, it } from 'vitest'
import { canHandleMentionKeydown, isMentionComposerTarget } from './mention_keyboard'

describe('mention autocomplete keyboard guard', () => {
  const textarea = { tagName: 'TEXTAREA', id: 'message-body' }

  it('accepts only the two message composer textareas', () => {
    expect(isMentionComposerTarget(textarea)).toBe(true)
    expect(isMentionComposerTarget({ tagName: 'TEXTAREA', id: 'direct-message-body' })).toBe(true)
    expect(isMentionComposerTarget({ tagName: 'TEXTAREA', id: 'search-input' })).toBe(false)
    expect(isMentionComposerTarget({ tagName: 'INPUT', id: 'message-body' })).toBe(false)
  })

  it('ignores native IME composition signals before keyboard selection', () => {
    expect(canHandleMentionKeydown({ target: textarea }, false)).toBe(true)
    expect(canHandleMentionKeydown({ target: textarea, isComposing: true }, false)).toBe(false)
    expect(canHandleMentionKeydown({ target: textarea, keyCode: 229 }, false)).toBe(false)
    expect(canHandleMentionKeydown({ target: textarea }, true)).toBe(false)
  })
})
