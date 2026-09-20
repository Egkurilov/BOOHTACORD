import { describe, expect, it, vi } from 'vitest'

import { searchDirectMessageHistory } from './direct_message_search_client'

describe('direct-message search client', () => {
  it('searches only the selected pair with same-origin credentials', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      messages: [{
        id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', body: 'игра запущена',
        created_at: '2026-09-18T12:00:00Z', revision: 1,
      }],
      next_cursor: 'message-2',
    })))

    await expect(searchDirectMessageHistory('dm-1', '"игра"', 'message-2', 20, request)).resolves.toMatchObject({
      nextCursor: 'message-2', messages: [{ directMessageId: 'dm-1', body: 'игра запущена' }],
    })
    expect(request).toHaveBeenCalledWith(
      '/api/v1/direct-messages/dm-1/search?query=%22%D0%B8%D0%B3%D1%80%D0%B0%22&before=message-2&limit=20',
      expect.objectContaining({ method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' } }),
    )
  })

  it('rejects malformed private search results', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      messages: [{ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', body: 'игра', created_at: '2026-09-18T12:00:00Z', revision: 0 }],
    })))

    await expect(searchDirectMessageHistory('dm-1', 'игра', undefined, 20, request)).rejects.toThrow('некорректные результаты')
  })
})
