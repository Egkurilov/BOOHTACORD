import { describe, expect, it, vi } from 'vitest'

import { searchTextMessages } from './text_message_search_client'

describe('text message search client', () => {
  it('searches the selected channel through the authenticated same-origin endpoint', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      messages: [{
        id: 'message-1', channel_id: 'text-1', author_id: 'user-1', body: 'игра запущена',
        created_at: '2026-09-18T12:00:00Z', revision: 1,
      }],
      next_cursor: 'message-2',
    })))

    await expect(searchTextMessages('text-1', '"игра"', 'message-2', 20, request)).resolves.toMatchObject({
      nextCursor: 'message-2', messages: [{ body: 'игра запущена', revision: 1 }],
    })
    expect(request).toHaveBeenCalledWith(
      '/api/v1/channels/text-1/search?query=%22%D0%B8%D0%B3%D1%80%D0%B0%22&before=message-2&limit=20',
      expect.objectContaining({ method: 'GET', credentials: 'same-origin' }),
    )
  })

  it('rejects malformed search results rather than displaying them', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      messages: [{ id: 'message-1', channel_id: 'text-1', author_id: 'user-1', body: 'игра', created_at: '2026-09-18T12:00:00Z', revision: 0 }],
    })))

    await expect(searchTextMessages('text-1', 'игра', undefined, 20, request)).rejects.toThrow('некорректные результаты')
  })
})
