import { describe, expect, it, vi } from 'vitest'

import { listMyMentions } from './mentions_inbox_client'

describe('caller mentions inbox client', () => {
  it('loads ID-only mention metadata from the session endpoint without caching', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ mentions: [{
      kind: 'DIRECT_MESSAGE', message_id: '22222222-2222-4222-8222-222222222222',
      conversation_id: '33333333-3333-4333-8333-333333333333', author_id: '44444444-4444-4444-8444-444444444444', created_at: '2026-10-08T10:00:00Z',
    }], next_cursor: 'opaque-cursor' })))
    await expect(listMyMentions('opaque-cursor', request)).resolves.toMatchObject({
      nextCursor: 'opaque-cursor', mentions: [{ kind: 'DIRECT_MESSAGE', messageId: '22222222-2222-4222-8222-222222222222' }],
    })
    expect(request).toHaveBeenCalledWith('/api/v1/mentions?before=opaque-cursor', expect.objectContaining({
      method: 'GET', credentials: 'same-origin', cache: 'no-store',
    }))
  })

  it('rejects mention responses that include content or malformed IDs', async () => {
    const withBody = vi.fn().mockResolvedValue(new Response(JSON.stringify({ mentions: [{
      kind: 'CHANNEL', message_id: '22222222-2222-4222-8222-222222222222', conversation_id: '33333333-3333-4333-8333-333333333333',
      author_id: '44444444-4444-4444-8444-444444444444', created_at: '2026-10-08T10:00:00Z', body: 'private',
    }] })))
    await expect(listMyMentions(undefined, withBody)).rejects.toThrow('некорректные результаты')
    const malformed = vi.fn().mockResolvedValue(new Response(JSON.stringify({ mentions: [{ kind: 'DIRECT_MESSAGE', message_id: 'bad', conversation_id: 'dm-1', author_id: 'user-1', created_at: 'now' }] })))
    await expect(listMyMentions(undefined, malformed)).rejects.toThrow('некорректные результаты')
  })
})
