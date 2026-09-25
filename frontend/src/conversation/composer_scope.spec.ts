import { describe, expect, it } from 'vitest'

import { useComposerScope } from './composer_scope'

describe('conversation composer scope', () => {
  it('clears text, reply, mentions and files when switching conversations', () => {
    const scope = useComposerScope<{ id: string }, { id: string }>()
    scope.draft.value = 'Текст A'
    scope.replyTarget.value = { id: 'reply-a' }
    scope.attachments.value = [{ id: 'file-a' }]
    scope.mentionUserIds.value = ['user-a']
    scope.attachmentPending.value = true
    const old = scope.snapshot('conversation-a')
    scope.reset()
    expect(scope.draft.value).toBe('')
    expect(scope.replyTarget.value).toBeNull()
    expect(scope.attachments.value).toEqual([])
    expect(scope.mentionUserIds.value).toEqual([])
    expect(scope.attachmentPending.value).toBe(false)
    expect(scope.unchanged(old, 'conversation-b')).toBe(false)
  })

  it('never clears a new A draft after A→B→A or a late response to an edited draft', () => {
    const scope = useComposerScope<{ id: string }, { id: string }>()
    scope.draft.value = 'same text'
    const first = scope.snapshot('a')
    scope.reset()
    scope.draft.value = 'same text'
    expect(scope.unchanged(first, 'a')).toBe(false)
    const second = scope.snapshot('a')
    scope.draft.value = 'new text'
    expect(scope.unchanged(second, 'a')).toBe(false)
  })

  it('compares retry with the exact reply, mention and attachment IDs', () => {
    const scope = useComposerScope<{ id: string }, { id: string }>()
    scope.draft.value = 'Сообщение'
    scope.replyTarget.value = { id: 'reply-a' }
    scope.attachments.value = [{ id: 'file-a' }]
    scope.mentionUserIds.value = ['user-a']
    const message = { body: 'Сообщение', replyToId: 'reply-a', attachments: [{ id: 'file-a' }], mentionUserIds: ['user-a'] }
    expect(scope.matchesMessage(message)).toBe(true)
    expect(scope.matchesMessage({ ...message, attachments: [{ id: 'file-b' }] })).toBe(false)
    scope.clear()
    expect(scope.attachments.value).toEqual([])
    expect(scope.attachmentClearToken.value).toBe(1)
  })
})
