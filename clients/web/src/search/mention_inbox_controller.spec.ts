import { describe, expect, it, vi } from 'vitest'

import { createMentionInboxController } from './mention_inbox_controller'
import type { MentionInboxItem, MentionInboxPage } from './mentions_inbox_client'

const item = (id: string): MentionInboxItem => ({ kind: 'CHANNEL', messageId: id, conversationId: 'channel-1', authorId: 'author-1', createdAt: '2026-10-08T10:00:00Z' })

describe('mention inbox paging', () => {
  it('refreshes newest-first and deduplicates items across cursor pages', async () => {
    const load = vi.fn<() => Promise<MentionInboxPage>>()
      .mockResolvedValueOnce({ mentions: [item('first')], nextCursor: 'cursor-1' })
      .mockResolvedValueOnce({ mentions: [item('first'), item('second')] })
    const inbox = createMentionInboxController(load)
    await inbox.refresh()
    await inbox.loadMore()
    expect(load).toHaveBeenNthCalledWith(2, 'cursor-1')
    expect(inbox.mentions.value.map(({ messageId }) => messageId)).toEqual(['first', 'second'])
    expect(inbox.nextCursor.value).toBe('')
  })

  it('ignores a pending page from the previous conversation panel generation', async () => {
    let finish!: (page: MentionInboxPage) => void
    const load = vi.fn<() => Promise<MentionInboxPage>>()
      .mockImplementationOnce(() => new Promise((resolve) => { finish = resolve }))
      .mockResolvedValueOnce({ mentions: [item('newest')] })
    const inbox = createMentionInboxController(load)
    const old = inbox.refresh()
    await inbox.refresh()
    finish({ mentions: [item('stale')] })
    await old
    expect(inbox.mentions.value.map(({ messageId }) => messageId)).toEqual(['newest'])
  })
})
