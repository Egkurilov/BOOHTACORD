import { describe, expect, it, vi } from 'vitest'

import { searchMessages } from './search_messages_client'

describe('unified message search client', () => {
  it('searches a current channel through the same-origin session endpoint', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      messages: [{ id: '44444444-4444-4444-8444-444444444444', kind: 'CHANNEL', channel_id: '22222222-2222-4222-8222-222222222222', author_id: '11111111-1111-4111-8111-111111111111', body: 'игра запущена', created_at: '2026-09-24T12:00:00Z', revision: 1 }],
      next_cursor: 'opaque-cursor',
    })))

    await expect(searchMessages({ query: '"игра"', channelId: '22222222-2222-4222-8222-222222222222', authorId: '11111111-1111-4111-8111-111111111111', hasAttachment: false, before: 'opaque-cursor', limit: 20 }, request)).resolves.toMatchObject({
      nextCursor: 'opaque-cursor', messages: [{ kind: 'CHANNEL', channelId: '22222222-2222-4222-8222-222222222222', body: 'игра запущена', revision: 1 }],
    })
    expect(request).toHaveBeenCalledWith(
      '/api/v1/search/messages?query=%22%D0%B8%D0%B3%D1%80%D0%B0%22&channel_id=22222222-2222-4222-8222-222222222222&author_id=11111111-1111-4111-8111-111111111111&has_attachment=false&before=opaque-cursor&limit=20',
      expect.objectContaining({ method: 'GET', credentials: 'same-origin' }),
    )
  })

  it('rejects malformed result scopes and mutually exclusive filters', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [{ id: 'message-1', kind: 'DIRECT_MESSAGE', channel_id: 'unexpected', author_id: 'user-1', body: 'hidden', created_at: '2026-09-24T12:00:00Z', revision: 1 }] })))
    await expect(searchMessages({ query: 'x' }, request)).rejects.toThrow('некорректные результаты')
    await expect(searchMessages({ query: 'x', channelId: 'channel-1', directMessageId: 'dm-1' }, request)).rejects.toThrow('фильтр')
  })
})
