import { beforeEach, describe, expect, it } from 'vitest'

import { clearDraftIfRevision, clearDraftMemory, draftKey, draftMemoryEpoch, draftRevision, loadDraft, saveDraft } from './draft_memory'

beforeEach(clearDraftMemory)

describe('memory-only conversation drafts', () => {
  it('restores independent account, channel and DM drafts with reply, mentions and prepared attachments', () => {
    const first = draftKey('account-a', 'CHANNEL', 'same-id')
    const otherAccount = draftKey('account-b', 'CHANNEL', 'same-id')
    const dm = draftKey('account-a', 'DIRECT_MESSAGE', 'same-id')
    saveDraft(first, { body: 'текст', replyTarget: { id: 'reply-a' }, mentionUserIds: ['member-a'], attachments: [{ id: 'file-a' }] })
    expect(loadDraft(first)).toEqual({ body: 'текст', replyTarget: { id: 'reply-a' }, mentionUserIds: ['member-a'], attachments: [{ id: 'file-a' }] })
    expect(loadDraft(otherAccount)).toBeNull()
    expect(loadDraft(dm)).toBeNull()
  })

  it('removes sent and signed-out drafts without retaining the body', () => {
    const key = draftKey('account-a', 'CHANNEL', 'channel-a')
    saveDraft(key, { body: 'секрет', replyTarget: null, mentionUserIds: [], attachments: [] })
    saveDraft(key, { body: '', replyTarget: null, mentionUserIds: [], attachments: [] })
    expect(loadDraft(key)).toBeNull()
    saveDraft(key, { body: 'ещё', replyTarget: null, mentionUserIds: [], attachments: [] })
    const beforeLogout = draftMemoryEpoch()
    clearDraftMemory()
    expect(draftMemoryEpoch()).toBeGreaterThan(beforeLogout)
    expect(loadDraft(key)).toBeNull()
  })

  it('does not clear a newer draft after a delayed acknowledgement of an earlier version', () => {
    const key = draftKey('account-a', 'CHANNEL', 'channel-a')
    saveDraft(key, { body: 'первое', replyTarget: null, mentionUserIds: [], attachments: [] })
    const sentRevision = draftRevision(key)
    saveDraft(key, { body: 'новое', replyTarget: null, mentionUserIds: [], attachments: [] })
    expect(clearDraftIfRevision(key, sentRevision)).toBe(false)
    expect(loadDraft<{ id: string }, { id: string }>(key)?.body).toBe('новое')
    expect(clearDraftIfRevision(key, draftRevision(key))).toBe(true)
    expect(loadDraft(key)).toBeNull()
  })
})
