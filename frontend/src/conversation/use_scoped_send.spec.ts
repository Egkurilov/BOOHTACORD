import { beforeEach, describe, expect, it } from 'vitest'
import { clearDraftMemory, draftKey, loadDraft, saveDraft } from './draft_memory'
import { useComposerScope } from './composer_scope'
import { useScopedSend } from './use_scoped_send'

beforeEach(clearDraftMemory)

describe('scoped send acknowledgement', () => {
  it('clears only the sent revision after navigation and leaves the new conversation untouched', async () => {
    const composer = useComposerScope<{ id: string }, { id: string }>()
    let current = 'text-a'
    composer.draft.value = 'hello'
    const key = draftKey('account', 'CHANNEL', current)
    saveDraft(key, { body: 'hello', replyTarget: null, attachments: [], mentionUserIds: [] })
    let acknowledge!: (value: boolean) => void
    const pending = new Promise<boolean>((resolve) => { acknowledge = resolve })
    const actions = useScopedSend('account', 'CHANNEL', () => current, composer, () => true, () => pending, async () => false)
    const sending = actions.send()
    current = 'text-b'
    composer.clear()
    composer.draft.value = 'next'
    acknowledge(true)
    await sending
    expect(loadDraft(key)).toBeNull()
    expect(composer.draft.value).toBe('next')
  })

  it('preserves an edited draft when the original send completes', async () => {
    const composer = useComposerScope<{ id: string }, { id: string }>()
    const key = draftKey('account', 'CHANNEL', 'text-a')
    composer.draft.value = 'first'
    saveDraft(key, { body: 'first', replyTarget: null, attachments: [], mentionUserIds: [] })
    let acknowledge!: (value: boolean) => void
    const pending = new Promise<boolean>((resolve) => { acknowledge = resolve })
    const actions = useScopedSend('account', 'CHANNEL', () => 'text-a', composer, () => true, () => pending, async () => false)
    const sending = actions.send()
    composer.draft.value = 'revised'
    saveDraft(key, { body: 'revised', replyTarget: null, attachments: [], mentionUserIds: [] })
    acknowledge(true)
    await sending
    expect(loadDraft<{ id: string }, { id: string }>(key)?.body).toBe('revised')
    expect(composer.draft.value).toBe('revised')
  })
})
