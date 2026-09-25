import { describe, expect, it, vi } from 'vitest'

import { advanceTextReadCursor } from './text_read_cursor_client'

describe('TEXT read cursor client', () => {
  it('advances only the caller cursor with an authenticated PUT', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ channel_id: 'text-1', message_id: 'message-2', message_created_at: '2026-09-25T00:00:00Z' })))
    await expect(advanceTextReadCursor('text-1', 'message-2', request)).resolves.toMatchObject({ channelId: 'text-1', messageId: 'message-2' })
    expect(request).toHaveBeenCalledWith('/api/v1/channels/text-1/read-cursor', {
      method: 'PUT', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ message_id: 'message-2' }),
    })
  })

  it('rejects failed or mismatched server responses', async () => {
    await expect(advanceTextReadCursor('text-1', 'message-2', vi.fn().mockResolvedValue(new Response(null, { status: 404 })))).rejects.toThrow('404')
    const wrong = vi.fn().mockResolvedValue(new Response(JSON.stringify({ channel_id: 'text-2', message_id: 'message-2', message_created_at: '2026-09-25T00:00:00Z' })))
    await expect(advanceTextReadCursor('text-1', 'message-2', wrong)).rejects.toThrow('некоррект')
  })
})
