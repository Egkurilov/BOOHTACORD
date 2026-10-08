import { describe, expect, it } from 'vitest'

import { targetForMention } from './mention_target'
import type { MentionInboxItem } from './mentions_inbox_client'

const mention: MentionInboxItem = {
  kind: 'DIRECT_MESSAGE', messageId: 'message-1', conversationId: 'dm-1', authorId: 'author-1', createdAt: '2026-10-08T10:00:00Z',
}

describe('mention exact jump target', () => {
  it('preserves the message ID only for currently readable TEXT or caller DM', () => {
    expect(targetForMention({ ...mention, kind: 'CHANNEL', conversationId: 'channel-1' }, [{ id: 'channel-1', kind: 'TEXT' }], [])).toEqual({ kind: 'CHANNEL', conversationId: 'channel-1', messageId: 'message-1' })
    expect(targetForMention(mention, [], ['dm-1'])).toEqual({ kind: 'DIRECT_MESSAGE', conversationId: 'dm-1', messageId: 'message-1' })
  })

  it('rejects unavailable channels, non-TEXT channels, and foreign DMs', () => {
    expect(targetForMention({ ...mention, kind: 'CHANNEL', conversationId: 'missing' }, [], ['dm-1'])).toBeNull()
    expect(targetForMention({ ...mention, kind: 'CHANNEL', conversationId: 'voice-1' }, [{ id: 'voice-1', kind: 'VOICE' }], ['dm-1'])).toBeNull()
    expect(targetForMention(mention, [], ['another-dm'])).toBeNull()
  })
})
